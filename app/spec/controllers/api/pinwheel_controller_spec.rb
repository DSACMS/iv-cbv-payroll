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

    it "tracks a NewRelic event" do
      expect(NewRelicEventTracker)
        .to receive(:track)
        .with("ApplicantBeganLinkingEmployer", hash_including(
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

  describe "#user_action" do
    let(:cbv_flow) { create :cbv_flow }
    let(:valid_params) do
      { pinwheel: { event_name: event_name, attributes: event_attributes } }
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

        it "tracks an event with NewRelic (with selected_tab = platform)" do
          expect(NewRelicEventTracker).to receive(:track).with("ApplicantSelectedEmployerOrPlatformItem", {
            timestamp: be_a(Integer),
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            item_type: "platform",
            item_id: "123",
            item_name: "Test Payroll Provider",
            is_default_option: "true",
            locale: "en"
          }.stringify_keys)
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

        it "tracks an event with NewRelic (with selected_tab = employer)" do
          expect(NewRelicEventTracker).to receive(:track).with("ApplicantSelectedEmployerOrPlatformItem", {
            timestamp: be_a(Integer),
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            item_type: "employer",
            item_id: "123",
            item_name: "Test Employer",
            is_default_option: "true",
            locale: "en"
          }.stringify_keys)
          post :user_action, params: valid_params
        end
      end
    end
  end
end
