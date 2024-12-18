require "rails_helper"

RSpec.describe Caseworker::CbvFlowInvitationsController do
  let(:nyc_user) { create(:user, email: "test@test.com", site_id: 'nyc') }
  let(:ma_user) { create(:user, email: "test@test.com", site_id: 'ma') }
  let(:ma_params) { { site_id: "ma" } }
  let(:valid_params) do
    attributes_for(:cbv_flow_invitation, :nyc)
  end

  describe "#new" do
    context "without authentication" do
      it "redirects to the sso login page" do
        get :new, params: valid_params
        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context "with an invalid site id" do
      it "raises a routing error" do
        expect {
          get :new, params: valid_params.tap { |p| p[:site_id] = "this-is-not-a-site-id" }
        }.to raise_error(ActionController::UrlGenerationError)
        expect response.status == 404
      end
    end

    context "with authentication" do
      context "when site_id is nyc" do
        before do
          sign_in nyc_user
        end

        render_views

        it "renders the nyc fields" do
          get :new, params: valid_params
          expect(response).to be_successful
        end

        it "does not permit access to the ma page" do
          get :new, params: ma_params

          expect(response).to redirect_to(root_url)
        end
      end

      context "when site_id is ma" do
        let(:site_id) { "ma" }

        before do
          stub_site_config_value("ma", "staff_portal_enabled", true)
          sign_in ma_user
        end

        render_views

        it "renders the ma fields" do
          get :new, params: ma_params
          expect(response).to be_successful
        end

        it "does not permit access to the nyc page" do
          get :new, params: { site_id: "nyc" }
          expect(response).to redirect_to(root_url)
        end
      end
    end
  end

  describe "#create" do
    let(:site_id) { "nyc" }


    context "without authentication" do
      it "redirects to the homepage without creating any invitation" do
        expect_any_instance_of(CbvInvitationService).not_to receive(:invite)

        post :create, params: valid_params

        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context "with authentication" do
      before do
        sign_in nyc_user
      end

      it "sends an invitation" do
        post :create, params: {
          site_id: 'nyc',
          cbv_flow_invitation: valid_params
        }

        expect(response).to redirect_to(caseworker_dashboard_url(site_id: valid_params[:site_id]))
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
