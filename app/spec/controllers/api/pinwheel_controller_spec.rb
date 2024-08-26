require "rails_helper"

RSpec.describe Api::PinwheelController do
  include PinwheelApiHelper

  context "#create_token" do
    let(:cbv_flow) { create(:cbv_flow) }
    let(:valid_params) do
      {
        pinwheel: { response_type: "employer", id: "123" }
      }
    end

    before do
      session[:cbv_flow_id] = cbv_flow.id
      stub_create_token_response
    end

    it "creates a link token with Pinwheel" do
      post :create_token, params: valid_params

      expect(JSON.parse(response.body))
        .to include("token" => be_a(String))
    end

    describe "when the button is pressed without an employer or ID" do
      let(:valid_params) do
        {
          pinwheel: { response_type: "", id: "" }
        }
      end

      it "still creates a link token with Pinwheel" do
        post :create_token, params: valid_params

        expect(JSON.parse(response.body))
          .to include("token" => be_a(String))
      end
    end
  end
end
