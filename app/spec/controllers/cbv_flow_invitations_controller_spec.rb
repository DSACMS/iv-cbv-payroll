require "rails_helper"

RSpec.describe CbvFlowInvitationsController do
  let(:invite_secret) { "FAKE_INVITE_SECRET" }
  let(:site_id) { "nyc" }

  let(:user) { User.create(email: "test@test.com", site_id: 'ma') }

  around do |ex|
    stub_environment_variable("CBV_INVITE_SECRET", invite_secret, &ex)
  end

  let(:sandbox_params) { { site_id: "sandbox", secret: invite_secret } }
  let(:nyc_params) { { site_id: "nyc", secret: invite_secret } }
  let(:ma_params) { { site_id: "ma", secret: invite_secret } }

  describe "#new" do
    context "without authentication" do
      it "redirects to the sso login page" do
        get :new, params: valid_params.except(:secret)

        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context "with an invalid site id" do
      it "redirects to the homepage" do
        get :new, params: valid_params.tap { |p| p[:site_id] = "this-is-not-a-site-id" }

        expect(response).to redirect_to(root_url)
      end
    end

    context "with authentication" do
      before do
        sign_in user
      end

      render_views

      context "when site_id is nyc" do
        let(:site_id) { "nyc" }

        it "renders the nyc fields" do
          get :new, params: nyc_params

          expect(response.body).to include("first_name")
          expect(response.body).to include("middle_name")
          expect(response.body).to include("last_name")
          expect(response.body).to include("client_id_number")
          expect(response.body).to include("case_number")
          expect(response.body).to include("email_address")
          expect(response.body).to include("snap_application_date")
        end
      end

      context "when site_id is ma" do
        let(:site_id) { "ma" }

        it "renders the ma fields" do
          get :new, params: ma_params

          expect(response.body).to include("first_name")
          expect(response.body).to include("middle_name")
          expect(response.body).to include("last_name")
          expect(response.body).to include("agency_id_number")
          expect(response.body).to include("email_address")
          expect(response.body).to include("snap_application_date")
          expect(response.body).to include("beacon_id")
        end
      end
    end
  end

  describe "#create" do
    let(:cbv_flow_invitation_params) do
      {
        email_address: "test@example.com",
        case_number: "ABC1234"
      }
    end
    let(:valid_params) do
      {
        secret: invite_secret,
        site_id: site_id,
        cbv_flow_invitation: cbv_flow_invitation_params
      }
    end

    before do
      allow_any_instance_of(CbvInvitationService)
        .to receive(:invite)
        .with("test@example.com", "ABC1234", site_id)
    end

    context "without authentication" do
      before do
        valid_params[:secret] = nil
      end

      it "redirects to the homepage without creating any invitation" do
        expect_any_instance_of(CbvInvitationService).not_to receive(:invite)

        post :create, params: valid_params

        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context "with authentication" do
      before do
        sign_in user
      end

      it "sends an invitation" do
        expect_any_instance_of(CbvInvitationService)
          .to receive(:invite)
          .with("test@example.com", "ABC1234", site_id)

        post :create, params: valid_params

        expect(response).to redirect_to(root_url)
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
            .with("bad-email@", "ABC1234", site_id)
            .and_raise(StandardError.new("Some random error, like a bad email address or something."))
        end

        it "redirects back to the invitation form with the error" do
          expect_any_instance_of(CbvInvitationService)
            .to receive(:invite)
            .with("bad-email@", "ABC1234", site_id)

          post :create, params: broken_params

          expect(response).to redirect_to(new_invitation_path(secret: broken_params[:secret]))
          expect(controller.flash.alert).to include("Some random error")
        end
      end
    end
  end
end