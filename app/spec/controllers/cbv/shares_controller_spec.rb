require "rails_helper"

RSpec.describe Cbv::SharesController do
  include PinwheelApiHelper

  let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", pinwheel_token_id: "abc-def-ghi", site_id: "nyc") }

  describe "#show" do
    render_views

    it "renders" do
      get :show
      expect(response).to be_successful
    end
  end

  describe "#update" do
    before do
      stub_request_end_user_paystubs_response
      stub_request_end_user_accounts_response
      session[:cbv_flow_id] = cbv_flow.id
    end

    around do |ex|
      stub_environment_variable("SLACK_TEST_EMAIL", "test@example.com", &ex)
    end

    context "when confirmation_code is blank" do
      it "generates a new confirmation code" do
        expect(cbv_flow.confirmation_code).to be_blank
        put :update
        expect(cbv_flow.reload.confirmation_code).not_to be_blank
      end

      it "generates a new confirmation code with a prefix" do
        expect(cbv_flow.confirmation_code).to be_blank
        put :update
        expect(cbv_flow.reload.confirmation_code).to start_with("NYC")
      end
    end

    context "when confirmation_code already exists" do
      let(:existing_confirmation_code) { "NYC0000" }

      before do
        cbv_flow.update(confirmation_code: existing_confirmation_code)
      end

      it "does not override the existing confirmation code" do
        expect(cbv_flow.reload.confirmation_code).to eq(existing_confirmation_code)
        put :update
        # ensure that the confirmation code is not changed
        expect(cbv_flow.reload.confirmation_code).to eq(existing_confirmation_code)
      end
    end

    context "when sending an email to the caseworker" do
      let(:email_address) { "test@example.com" }

      it "sends the email" do
        expect do
          post :update
        end.to change { ActionMailer::Base.deliveries.count }.by(1)

        email = ActionMailer::Base.deliveries.last
        expect(email.to).to eq([email_address])
        expect(email.subject).to eq("Applicant Income Verification: ABC1234")
      end

      it "redirects to success screen" do
        post :update
        expect(response).to redirect_to({ controller: :successes, action: :show })
      end

      it "displays a notice" do
        post :update
        expect(flash[:notice]).to be_present
      end
    end
  end
end
