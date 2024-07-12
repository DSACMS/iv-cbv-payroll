require "rails_helper"

RSpec.describe Cbv::PaymentDetailsController do
  include PinwheelApiHelper

  describe "#show" do
    render_views

    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", pinwheel_token_id: "abc-def-ghi") }

    before do
      session[:cbv_flow_id] = cbv_flow.id
      stub_request_end_user_accounts_response
      stub_request_end_user_paystubs_response
      stub_request_employment_info_response
      stub_request_income_metadata_response
    end

    it "renders properly" do
      get :show, params: { user: { account_id: '123456789012345678901234567890123456' } }
      expect(response).to be_successful
    end
  end
end
