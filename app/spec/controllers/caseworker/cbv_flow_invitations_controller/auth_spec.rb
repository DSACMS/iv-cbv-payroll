require "rails_helper"

RSpec.describe Caseworker::CbvFlowInvitationsController do
  let(:nyc_user) { create(:user, email: "test@test.com", site_id: 'nyc') }
  let(:ma_user) { create(:user, email: "test@test.com", site_id: 'ma') }
  let(:ma_params) { { site_id: "ma" } }
  let(:nyc_params) { { site_id: "nyc" } }

  describe "#new" do
    let(:valid_params) { nyc_params }

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
        let(:site_id) { "nyc" }

        before do
          sign_in nyc_user
        end

        render_views

        it "renders the nyc fields" do
          get :new, params: nyc_params
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
          sign_in ma_user
        end

        render_views

        it "renders the ma fields" do
          get :new, params: ma_params
          expect(response).to be_successful
        end

        it "does not permit access to the nyc page" do
          get :new, params: nyc_params

          expect(response).to redirect_to(root_url)
        end
      end
    end
  end

  describe "#create" do
    let(:site_id) { "nyc" }
    let(:cbv_flow_invitation_params) do
      {
        email_address: "test@example.com",
        case_number: "ABC1234"
      }
    end
    let(:valid_params) do
      {
        site_id: site_id,
        cbv_flow_invitation: cbv_flow_invitation_params
      }
    end

    before do
      allow_any_instance_of(CbvInvitationService)
        .to receive(:invite)
    end

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
        expect_any_instance_of(CbvInvitationService)
          .to receive(:invite)
          .with(hash_including(email_address: "test@example.com", case_number: "ABC1234", site_id: site_id), nyc_user)

        post :create, params: valid_params

        expect(response).to redirect_to(caseworker_dashboard_url(site_id: valid_params[:site_id]))
      end

      context "when the CbvInvitationService has an error" do
        let(:broken_params) do
          valid_params.tap do |params|
            params[:cbv_flow_invitation][:email_address] = "bad-email@"
          end
        end

        before do
          allow_any_instance_of(CbvInvitationService)
            .to receive(:invite)
            .with(hash_including(email_address: "bad-email@", case_number: "ABC1234", site_id: site_id), nyc_user)
            .and_raise(StandardError.new("Some random error, like a bad email address or something."))
        end

        it "redirects back to the invitation form with the error" do
          expect_any_instance_of(CbvInvitationService)
            .to receive(:invite)
            .with(hash_including(email_address: "bad-email@", case_number: "ABC1234", site_id: site_id), nyc_user)

          post :create, params: broken_params

          expect(response).to redirect_to(new_invitation_path(site_id: broken_params[:site_id]))
          expect(controller.flash.alert).to include("Some random error")
        end
      end
    end
  end
end
