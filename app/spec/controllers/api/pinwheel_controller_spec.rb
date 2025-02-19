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

    it "tracks a Mixpanel event" do
      expect_any_instance_of(MixpanelEventTracker)
        .to receive(:track)
        .with("ApplicantBeganLinkingEmployer", anything, hash_including(
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
          response_type: "employer",
        ))
      post :create_token, params: valid_params
    end

    it "tracks a NewRelic event" do
      expect_any_instance_of(NewRelicEventTracker)
        .to receive(:track)
        .with("ApplicantBeganLinkingEmployer", anything, hash_including(
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
          response_type: "employer",
        ))
      post :create_token, params: valid_params
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
