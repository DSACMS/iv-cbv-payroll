require 'rails_helper'

RSpec.describe Api::HelpController, type: :controller do
  describe "POST #user_action" do
    let(:valid_params) do
      {
        event_name: "ApplicantOpenedHelpModal",
        source: "banner"
      }
    end

    context "when tracking a valid event" do
      it "tracks an event with Mixpanel" do
        expect_any_instance_of(MixpanelEventTracker).to receive(:track).with("ApplicantOpenedHelpModal", anything, hash_including(
          timestamp: be_a(Integer),
          source: "banner"
        ))
        post :user_action, params: valid_params
      end

      it "tracks an event with NewRelic" do
        expect_any_instance_of(NewRelicEventTracker).to receive(:track).with("ApplicantOpenedHelpModal", anything, hash_including(
          timestamp: be_a(Integer),
          source: "banner"
        ))
        post :user_action, params: valid_params
      end

      it "returns a success response" do
        post :user_action, params: valid_params
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ "status" => "ok" })
      end
    end

    context "when tracking an invalid event" do
      let(:invalid_params) do
        {
          event_name: "InvalidEvent",
          source: "banner"
        }
      end

      it "returns an error response in production" do
        allow(Rails.env).to receive(:production?).and_return(true)
        post :user_action, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq({ "status" => "error" })
      end

      it "raises an error in non-production" do
        allow(Rails.env).to receive(:production?).and_return(false)
        expect {
          post :user_action, params: invalid_params
        }.to raise_error('Unknown Event Type "InvalidEvent"')
      end
    end
  end
end 