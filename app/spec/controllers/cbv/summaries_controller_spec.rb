require "rails_helper"

RSpec.describe Cbv::SummariesController do
  include PinwheelApiHelper

  describe "#show" do
    render_views

    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", pinwheel_token_id: "abc-def-ghi") }

    before do
      session[:cbv_flow_id] = cbv_flow.id
      stub_request_end_user_accounts_response
      stub_request_end_user_paystubs_response
    end

    it "renders properly" do
      get :show
      expect(response).to be_successful
    end

    context "when saving additional information for the caseworker" do
      let(:additional_information) { "This is some additional information for the caseworker" }

      it "saves and redirects to the next page" do
        expect do
          patch :update, params: { cbv_flow: { additional_information: additional_information } }
        end.to change { cbv_flow.reload.additional_information }
                 .from(nil)
                 .to(additional_information)

        expect(response).to redirect_to(cbv_flow_share_path)
      end
    end
  end
end
