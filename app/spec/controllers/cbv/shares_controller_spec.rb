require "rails_helper"

RSpec.describe Cbv::SharesController do
  include PinwheelApiHelper

  let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", pinwheel_token_id: "abc-def-ghi") }

  before do
    session[:cbv_flow_id] = cbv_flow.id
  end

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
    end

    around do |ex|
      stub_environment_variable("SLACK_TEST_EMAIL", "test@example.com", &ex)
    end

    context "when sending an email to the caseworker" do
      let(:email_address) { "test@example.com" }

      it "sends the email" do
        expect do
          post :update
        end.to change { ActionMailer::Base.deliveries.count }.by(1)

        email = ActionMailer::Base.deliveries.last
        expect(email.to).to eq([ email_address ])
        expect(email.subject).to eq("Applicant Income Verification: ABC1234")
      end

      it "redirects to success screen" do
        post :update
        expect(response).to redirect_to({ controller: :success, action: :show })
      end

      it "displays a notice" do
        post :update
        expect(flash[:notice]).to be_present
      end
    end
  end
end
