require "rails_helper"

RSpec.describe Cbv::SuccessesController do
  include PinwheelApiHelper

  describe "#show" do
    let(:cbv_flow) { create(:cbv_flow, :invited, confirmation_code: "SANDBOX12345") }

    before do
      pinwheel_stub_request_end_user_paystubs_response
      pinwheel_stub_request_end_user_accounts_response
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :show
        expect(response).to be_successful
      end

      it "shows confirmation code in view" do
        get :show
        expect(response.body).to include(cbv_flow.confirmation_code)
      end
    end
  end

  describe "#check_code" do
    render_views

    context "when confirmation code is present" do
      let(:cbv_flow) { create(:cbv_flow, :invited, confirmation_code: "SANDBOX12345") }

      before do
        session[:cbv_flow_id] = cbv_flow.id
      end

      it "returns a turbo stream with confirmation code" do
        get :check_code, format: :turbo_stream
        expect(response).to be_successful
        expect(response.body).to include(cbv_flow.confirmation_code)
      end

      it "does not include the confirmation code turbo frame" do
        get :check_code, format: :turbo_stream
        expect(response.body).not_to include('refresh="2"')
      end
    end

    context "when confirmation code is not present" do
      let(:cbv_flow) { create(:cbv_flow, :invited, confirmation_code: nil) }

      before do
        session[:cbv_flow_id] = cbv_flow.id
      end

      it "returns a turbo stream with a placeholder" do
        get :check_code, format: :turbo_stream
        expect(response).to be_successful
        expect(response.body).to include("—")
      end

      it "includes a turbo frame with refreshes" do
        get :check_code, format: :turbo_stream
        expect(response.body).to include('id="confirmation_code_refresh"')
        expect(response.body).to include('refresh="2"')
      end
    end

    context "when checking for confirmation code" do
      let(:cbv_flow) { create(:cbv_flow, :invited, confirmation_code: nil) }

      before do
        session[:cbv_flow_id] = cbv_flow.id
      end

      it "reloads the cbv flow record" do
        expect_any_instance_of(CbvFlow).to receive(:reload).and_call_original
        get :check_code, format: :turbo_stream
      end
    end
  end
end
