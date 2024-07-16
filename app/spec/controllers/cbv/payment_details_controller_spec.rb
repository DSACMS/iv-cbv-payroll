# spec/controllers/cbv/payment_details_controller_spec.rb
require "rails_helper"

RSpec.describe Cbv::PaymentDetailsController do
  include PinwheelApiHelper

  describe "#show" do
    render_views

    let!(:cbv_flow) { CbvFlow.create!(case_number: "ABC1234", pinwheel_token_id: "abc-def-ghi") }
    let(:account_id) { SecureRandom.uuid }
    let(:comment) { "This is a test comment" }

    before do
      session[:cbv_flow_id] = cbv_flow.id
      stub_request_end_user_accounts_response
      stub_request_end_user_paystubs_response
      stub_request_employment_info_response
      stub_request_income_metadata_response
    end

    it "renders properly" do
      get :show, params: { user: { account_id: account_id } }
      expect(response).to be_successful
    end

    context "when account comment exists" do
      let(:updated_at) { Time.current.iso8601 }

      before do
        additional_information = { account_id => { comment: comment, updated_at: updated_at } }
        cbv_flow.update!(additional_information: additional_information.to_json)

        # Verify that the comment was saved
        loaded_info = JSON.parse(cbv_flow.reload.additional_information)
        expect(loaded_info[account_id]["comment"]).to eq(comment)
        
        expect(loaded_info[account_id]["updated_at"]).to eq(updated_at)
      end

      it "includes the account comment in the response" do
        get :show, params: { user: { account_id: account_id } }
        expect(response.body).to include(comment)
      end
    end

    context "when account comment does not exist" do
      it "does not include an account comment in the response" do
        get :show, params: { user: { account_id: account_id } }
        expect(response.body).not_to include(comment)
      end
    end
  end

  describe "#update" do
    let!(:cbv_flow) { CbvFlow.create!(case_number: "ABC1234", pinwheel_token_id: "abc-def-ghi") }
    let(:account_id) { SecureRandom.uuid }
    let(:comment) { "This is a test comment" }

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    it "updates the account comment" do
      patch :update, params: { user: { account_id: account_id }, cbv_flow: { additional_information: comment } }
      additional_information = JSON.parse(cbv_flow.reload.additional_information)
      expect(additional_information[account_id]["comment"]).to eq(comment)
    end
  end
end