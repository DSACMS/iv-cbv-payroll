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
        expect_any_instance_of(MixpanelEventTracker).to receive(:track).with("ApplicantOpenedHelpModal", anything, hash_including(
          timestamp: be_a(Integer),
          source: "banner",
          cbv_flow_id: cbv_flow.id
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
      let(:event_attributes) do
        {
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
  describe "#user_action" do
    let(:cbv_flow) { create :cbv_flow }
    let(:valid_params) do
      { events: { event_name: event_name, attributes: event_attributes } }
    end

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when tracking a ApplicantSelectedEmployerOrPlatformItem event" do
      let(:event_name) { "ApplicantSelectedEmployerOrPlatformItem" }

      context "when selecting the payroll providers tab" do
        let(:event_attributes) do
          {
            item_type: "platform",
            item_id: 123,
            item_name: "Test Payroll Provider",
            locale: "en",
            is_default_option: "true"
          }
        end

        it "tracks an event with Mixpanel (with selected_tab = platform)" do
          expect_any_instance_of(MixpanelEventTracker).to receive(:track).with("ApplicantSelectedEmployerOrPlatformItem", anything, hash_including(
            timestamp: be_a(Integer),
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            item_type: "platform",
            item_id: "123",
            item_name: "Test Payroll Provider",
            is_default_option: "true",
            locale: "en"
          ))
          post :user_action, params: valid_params
        end

        it "tracks an event with NewRelic (with selected_tab = platform)" do
          expect_any_instance_of(NewRelicEventTracker).to receive(:track).with("ApplicantSelectedEmployerOrPlatformItem", anything, hash_including(
            timestamp: be_a(Integer),
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            item_type: "platform",
            item_id: "123",
            item_name: "Test Payroll Provider",
            is_default_option: "true",
            locale: "en"
          ))
          post :user_action, params: valid_params
        end
      end

      context "when selecting the common employers tab" do
        let(:event_attributes) do
          {
            item_type: "employer",
            item_id: 123,
            item_name: "Test Employer",
            locale: "en",
            is_default_option: "true"
          }
        end

        it "tracks an event with Mixpanel (with selected_tab = employer)" do
          expect_any_instance_of(MixpanelEventTracker).to receive(:track).with("ApplicantSelectedEmployerOrPlatformItem", anything, hash_including(
            timestamp: be_a(Integer),
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            item_type: "employer",
            item_id: "123",
            item_name: "Test Employer",
            is_default_option: "true",
            locale: "en"
          ))
          post :user_action, params: valid_params
        end

        it "tracks an event with NewRelic (with selected_tab = employer)" do
          expect_any_instance_of(NewRelicEventTracker).to receive(:track).with("ApplicantSelectedEmployerOrPlatformItem", anything, hash_including(
            timestamp: be_a(Integer),
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            item_type: "employer",
            item_id: "123",
            item_name: "Test Employer",
            is_default_option: "true",
            locale: "en"
          ))
          post :user_action, params: valid_params
        end
      end
    end

    context "when tracking a PinwheelShowLoginPage event" do
      let(:event_name) { "PinwheelShowLoginPage" }
      let(:event_attributes) do
        {
          screen_name: "LOGIN",
          employer_name: "Bob's Burgers",
          platform_name: "Test Payroll Platform Name",
          locale: "en"
        }
      end

      it "tracks an event with Mixpanel" do
        expect_any_instance_of(MixpanelEventTracker).to receive(:track).with("ApplicantViewedPinwheelLoginPage", anything, hash_including(
          timestamp: be_a(Integer),
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
          locale: "en",
          screen_name: "LOGIN",
          employer_name: "Bob's Burgers",
          platform_name: "Test Payroll Platform Name"
        ))
        post :user_action, params: valid_params
      end

      # We detect the new name for these events in NewRelic because we change the name from within the :track method
      it "tracks an event with NewRelic" do
        expect_any_instance_of(NewRelicEventTracker).to receive(:track).with("ApplicantViewedPinwheelLoginPage", anything, hash_including(
          timestamp: be_a(Integer),
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
          locale: "en",
          screen_name: "LOGIN",
          employer_name: "Bob's Burgers",
          platform_name: "Test Payroll Platform Name"
        ))
        post :user_action, params: valid_params
      end
    end

    context "when tracking a UserManuallySwitchedLanguage event" do
      let(:event_name) { "UserManuallySwitchedLanguage" }
      let(:event_attributes) do
        {
          locale: "es"
        }
      end

      it "tracks an event with Mixpanel" do
        expect_any_instance_of(MixpanelEventTracker).to receive(:track).with("UserManuallySwitchedLanguage", anything, hash_including(
          timestamp: be_a(Integer),
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
          locale: "es"
        ))
        post :user_action, params: valid_params
      end

      it "tracks an event with NewRelic" do
        expect_any_instance_of(NewRelicEventTracker).to receive(:track).with("UserManuallySwitchedLanguage", anything, hash_including(
          timestamp: be_a(Integer),
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
          locale: "es"
        ))
        post :user_action, params: valid_params
      end
    end
  end
end
