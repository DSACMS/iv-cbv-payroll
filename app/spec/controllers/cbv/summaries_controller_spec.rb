require "rails_helper"

RSpec.describe Cbv::SummariesController do
  include PinwheelApiHelper

  describe "#show" do
    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", pinwheel_token_id: "abc-def-ghi", site_id: "sandbox") }

    before do
      session[:cbv_flow_id] = cbv_flow.id
      stub_request_end_user_accounts_response
      stub_request_end_user_paystubs_response
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :show
        expect(response).to be_successful
      end

      it "renders pdf properly" do
        get :show, format: :pdf
        expect(response).to be_successful
        expect(response.header['Content-Type']).to include 'pdf'
      end
    end

    context "for a completed CbvFlow" do
      let(:cbv_flow) do
        CbvFlow.create(
          case_number: "ABC1234",
          pinwheel_token_id: "abc-def-ghi",
          site_id: "sandbox",
          confirmation_code: "ABC1234"
        )
      end

      it "allows the user to download the PDF summary" do
        get :show, format: :pdf
        expect(response).to be_successful
        expect(response.header['Content-Type']).to include 'pdf'
      end

      it "redirects the user to the success page if the user goes back to the page" do
        get :show
        expect(response).to redirect_to(cbv_flow_success_path)
      end
    end
  end
end
