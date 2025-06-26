require "rails_helper"

RSpec.describe Caseworker::CbvFlowInvitationsController, type: :controller do
  let(:sandbox_user) { create(:user, email: "test@test.com", client_agency_id: 'sandbox') }
  let(:valid_params) do
    attributes_for(:cbv_flow_invitation, :sandbox).merge(
      cbv_applicant_attributes: attributes_for(:cbv_applicant, :sandbox)
    )
  end

  describe "#new" do
    context "without authentication" do
      it "redirects to the login page" do
        get :new, params: valid_params
        expect(response).to redirect_to(new_user_session_path(client_agency_id: 'sandbox'))
      end
    end

    context "with an invalid client agency id" do
      it "raises a routing error" do
        expect {
          get :new, params: valid_params.tap { |p| p[:client_agency_id] = "this-is-not-a-site-id" }
        }.to raise_error(ActionController::UrlGenerationError)
        expect response.status == 404
      end
    end

    context "with authentication" do
      context "when client_agency_id is sandbox" do
        before do
          stub_client_agency_config_value("sandbox", "staff_portal_enabled", true)
          sign_in sandbox_user
        end

        render_views

        it "renders the sandbox fields" do
          get :new, params: valid_params
          expect(response).to be_successful
        end

        it "does not permit access to other agency pages" do
          get :new, params: { client_agency_id: "az_des" }

          expect(response).to redirect_to(root_url)
        end
      end
    end
  end

  describe "#create" do
    let(:client_agency_id) { "sandbox" }

    context "without authentication" do
      it "redirects to the login page without creating any invitation" do
        expect_any_instance_of(CbvInvitationService).not_to receive(:invite)

        post :create, params: valid_params

        expect(response).to redirect_to(new_user_session_path(client_agency_id: 'sandbox'))
      end
    end

    context "with authentication" do
      before do
        stub_client_agency_config_value("sandbox", "staff_portal_enabled", true)
        sign_in sandbox_user
      end

      it "sends an invitation" do
        post :create, params: {
            client_agency_id: 'sandbox',
          cbv_flow_invitation: valid_params
        }

        expect(response).to redirect_to(caseworker_dashboard_url(client_agency_id: valid_params[:client_agency_id]))
      end

      context "when the CbvInvitationService has an error" do
        it "takes the user back to the invitation form with the error" do
          post :create, params: valid_params.merge(email_address: "bad-email@")
          expect(controller.flash[:alert]).to include(I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.email_address.invalid_format'))
        end
      end
    end
  end
end
