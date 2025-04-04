require "rails_helper"

RSpec.describe Api::ArgyleController do
  include ArgyleApiHelper

  context "#create" do
    let(:cbv_flow) { create(:cbv_flow) }

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when the Cbv Flow does not have an argyle_user_id" do
      before do
        stub_create_user_response
      end

      it "creates a user with Argyle, returning its token" do
        post :create

        expect(JSON.parse(response.body))
          .to include("user" => { "user_token" => be_a(String) })
      end

      it "tracks a Mixpanel event" do
        expect_any_instance_of(MixpanelEventTracker)
          .to receive(:track)
          .with("ApplicantBeganLinkingEmployer", anything, hash_including(
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
          ))
        post :create
      end

      it "tracks a NewRelic event" do
        expect_any_instance_of(NewRelicEventTracker)
          .to receive(:track)
          .with("ApplicantBeganLinkingEmployer", anything, hash_including(
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
          ))
        post :create
      end
    end

    context "when the CbvFlow already has an argyle_user_id" do
      let(:cbv_flow) { create(:cbv_flow, argyle_user_id: "foo-bar-baz") }

      before do
        stub_create_user_token_response
      end

      it "creates a token for the existing Argyle user" do
        post :create

        expect(JSON.parse(response.body))
          .to include("user" => { "user_token" => be_a(String) })
      end
    end
  end
end
