require "rails_helper"

RSpec.describe CbvFlowInvitationsController do
  let(:invite_secret) { "FAKE_INVITE_SECRET" }

  around do |ex|
    stub_environment_variable("CBV_INVITE_SECRET", invite_secret, &ex)
  end

  describe "#new" do
    context "without the invite secret" do
      it "redirects to the homepage" do
        get :new

        expect(response).to redirect_to(root_url)
      end
    end

    context "with the invite secret" do
      render_views

      it "renders properly" do
        get :new, params: { secret: invite_secret }

        expect(response).to be_successful
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
        cbv_flow_invitation: cbv_flow_invitation_params
      }
    end

    before do
      allow_any_instance_of(CbvInvitationService)
        .to receive(:invite)
        .with("test@example.com", "ABC1234")
    end

    context "without the invite secret" do
      before do
        valid_params[:secret] = nil
      end

      it "redirects to the homepage without creating any invitation" do
        expect_any_instance_of(CbvInvitationService).not_to receive(:invite)

        post :create, params: valid_params

        expect(response).to redirect_to(root_url)
      end
    end

    context "with the invite secret" do
      it "sends an invitation" do
        expect_any_instance_of(CbvInvitationService)
          .to receive(:invite)
          .with("test@example.com", "ABC1234")

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
            .with("bad-email@", "ABC1234")
            .and_raise(StandardError.new("Some random error, like a bad email address or something."))
        end

        it "redirects back to the invitation form with the error" do
          expect_any_instance_of(CbvInvitationService)
            .to receive(:invite)
            .with("bad-email@", "ABC1234")

          post :create, params: broken_params

          expect(response).to redirect_to(new_cbv_flow_invitation_path(secret: broken_params[:secret]))
          expect(controller.flash.alert).to include("Some random error")
        end
      end
    end
  end
end
