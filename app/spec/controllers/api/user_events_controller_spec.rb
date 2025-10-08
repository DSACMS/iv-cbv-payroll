require 'rails_helper'

RSpec.describe Api::UserEventsController, type: :controller do
  describe "POST #user_action" do
    let(:cbv_flow) { create :cbv_flow }
    let(:valid_params) do
      {
        events: {
          event_name: "ApplicantOpenedHelpModal",
          attributes: event_attributes
        }
      }
    end
    let(:invalid_params) do
      {
        events: {
          event_name: "InvalidEvent",
          attributes: event_attributes
        }
      }
    end

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when tracking a valid event" do
      let(:event_attributes) do
        {
          source: "banner"
        }
      end

      it "tracks an event with Mixpanel" do
        allow(EventTrackingJob).to receive(:perform_later)
        post :user_action, params: valid_params
        expect(EventTrackingJob).to have_received(:perform_later).with("ApplicantOpenedHelpModal", anything, hash_including(
          time: be_a(Integer),
          source: "banner",
          cbv_flow_id: cbv_flow.id
        ))
      end

      it "returns a success status" do
        post :user_action, params: valid_params
        expect(response).to have_http_status(:ok)
      end

      it "returns success response body" do
        post :user_action, params: valid_params
        expect(JSON.parse(response.body)).to eq({ "status" => "ok" })
      end
    end

    context "when tracking an invalid event" do
      let(:event_attributes) do
        {
          source: "banner"
        }
      end

      it "returns unprocessable content status in production" do
        allow(Rails.env).to receive(:production?).and_return(true)
        post :user_action, params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns error response body in production" do
        allow(Rails.env).to receive(:production?).and_return(true)
        post :user_action, params: invalid_params
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

  describe "#user_action" do
    let(:cbv_flow) { create :cbv_flow }
    let(:valid_params) do
      { events: { event_name: event_name, attributes: event_attributes } }
    end

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when tracking ApplicantSelectedEmployerOrPlatformItem with platform selection" do
      let(:event_name) { "ApplicantSelectedEmployerOrPlatformItem" }
      let(:event_attributes) do
        {
          item_type: "platform",
          item_id: 123,
          item_name: "Test Payroll Provider",
          locale: "en",
          is_default_option: "true"
        }
      end

      it "tracks platform selection event" do
        allow(EventTrackingJob).to receive(:perform_later)
        post :user_action, params: valid_params
        expect(EventTrackingJob).to have_received(:perform_later).with(
          "ApplicantSelectedEmployerOrPlatformItem",
          anything,
          hash_including(
            time: be_a(Integer),
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            item_type: "platform",
            item_id: "123",
            item_name: "Test Payroll Provider",
            is_default_option: "true",
            locale: "en"
          )
        )
      end
    end

    context "when tracking ApplicantSelectedEmployerOrPlatformItem" do
      let(:event_name) { "ApplicantSelectedEmployerOrPlatformItem" }
      let(:event_attributes) do
        {
          item_type: "employer",
          item_id: 123,
          item_name: "Test Employer",
          locale: "en",
          is_default_option: "true"
        }
      end

      it "tracks employer selection event" do
        allow(EventTrackingJob).to receive(:perform_later)
        post :user_action, params: valid_params
        expect(EventTrackingJob).to have_received(:perform_later).with(
          "ApplicantSelectedEmployerOrPlatformItem",
          anything,
          hash_including(
            time: be_a(Integer),
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            item_type: "employer",
            item_id: "123",
            item_name: "Test Employer",
            is_default_option: "true",
            locale: "en"
          )
        )
      end
    end

    context "when tracking a PinwheelShowLoginPage event" do
      let(:event_name) { "ApplicantViewedPinwheelLoginPage" }
      let(:event_attributes) do
        {
          screen_name: "LOGIN",
          employer_name: "Bob's Burgers",
          platform_name: "Test Payroll Platform Name",
          locale: "en"
        }
      end

      it "tracks Pinwheel login page view event" do
        allow(EventTrackingJob).to receive(:perform_later)
        post :user_action, params: valid_params
        expect(EventTrackingJob).to have_received(:perform_later).with("ApplicantViewedPinwheelLoginPage", anything, hash_including(
          time: be_a(Integer),
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
          locale: "en",
          screen_name: "LOGIN",
          employer_name: "Bob's Burgers",
          platform_name: "Test Payroll Platform Name"
        ))
      end
    end

    context "when tracking a UserManuallySwitchedLanguage event" do
      let(:event_name) { "ApplicantManuallySwitchedLanguage" }
      let(:event_attributes) do
        {
          locale: "es"
        }
      end

      it "tracks language switch event" do
        allow(EventTrackingJob).to receive(:perform_later)
        post :user_action, params: valid_params
        expect(EventTrackingJob).to have_received(:perform_later).with("ApplicantManuallySwitchedLanguage", anything, hash_including(
          time: be_a(Integer),
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
          locale: "es"
        ))
      end
    end

    context "when tracking a ApplicantConsentedToTerms event" do
      let(:event_name) { "ApplicantConsentedToTerms" }
      let(:event_attributes) { {} }

      it "tracks consent to terms event" do
        allow(EventTrackingJob).to receive(:perform_later)
        post :user_action, params: valid_params
        expect(EventTrackingJob).to have_received(:perform_later).with("ApplicantConsentedToTerms", anything, hash_including(
          time: be_a(Integer),
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id
        ))
      end
    end

    context "when tracking ApplicantViewedHelpText for 'who is this for' section" do
      let(:event_name) { "ApplicantViewedHelpText" }
      let(:event_attributes) do
        {
          section: "who_is_this_tool_for"
        }
      end

      it "tracks help text view event" do
        allow(EventTrackingJob).to receive(:perform_later)
        post :user_action, params: valid_params
        expect(EventTrackingJob).to have_received(:perform_later).with(
          "ApplicantViewedHelpText",
          anything,
          hash_including(
            time: be_a(Integer),
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            section: "who_is_this_tool_for"
          )
        )
      end
    end

    context "when tracking ApplicantViewedHelpText for 'what if I cant use this' section" do
      let(:event_name) { "ApplicantViewedHelpText" }
      let(:event_attributes) do
        {
          section: "what_if_i_cant_use_this_tool"
        }
      end

      it "tracks help text view event" do
        allow(EventTrackingJob).to receive(:perform_later)
        post :user_action, params: valid_params
        expect(EventTrackingJob).to have_received(:perform_later).with(
          "ApplicantViewedHelpText",
          anything,
          hash_including(
            time: be_a(Integer),
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            section: "what_if_i_cant_use_this_tool"
          )
        )
      end
    end
  end
end
