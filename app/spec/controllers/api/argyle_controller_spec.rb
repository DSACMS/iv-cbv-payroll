require "rails_helper"

RSpec.describe Api::ArgyleController do
  include ArgyleApiHelper

  describe "#create" do
    let(:cbv_flow) { create(:cbv_flow) }
    # get the argyle user id and item e.g. payroll/provider to include in the fetch_user_api_response stub
    let(:argyle_user_id) { argyle_load_relative_json_file('', 'response_create_user.json')["id"] }
    let(:argyle_item_id) { argyle_load_relative_json_file("bob", "request_user.json")["items_connected"].first }

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when the CbvFlow does not have an argyle_user_id" do
      before do
        stub_create_user_response
        argyle_stub_fetch_user_api_response('bob', {
          id: argyle_user_id
        })
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

      it "includes isSandbox flag in response" do
        argyle = double('argyle', create_user: {})

        allow(argyle).to receive(:fetch_user_api).and_return({})
        allow(CbvFlow).to receive(:find).and_return(cbv_flow)
        allow(controller).to receive(:argyle_for).and_return(argyle)
        allow(controller).to receive(:agency_config).and_return({
          cbv_flow.client_agency_id => double(argyle_environment: 'sandbox')
        })

        post :create

        expect(JSON.parse(response.body)["isSandbox"]).to eq(true)
      end
    end

    context "when the CbvFlow already has an argyle_user_id" do
      let(:cbv_flow) { create(:cbv_flow, argyle_user_id: "foo-bar-baz") }

      before do
        stub_create_user_token_response
        argyle_stub_fetch_user_api_response('bob', { id: cbv_flow.argyle_user_id })
      end

      it "creates a token for the existing Argyle user" do
        post :create

        expect(JSON.parse(response.body))
          .to include("user" => { "user_token" => be_a(String) })
      end
    end

    context "when the payroll account or employer has already been linked" do
      before do
        stub_create_user_response
        stub_create_user_token_response
        argyle_stub_fetch_user_api_response('bob', {
          id: argyle_user_id,
          items_connected: [ argyle_item_id ]
        })
      end

      context "if the payroll account is fully synced" do
        let(:cbv_flow) { create(:cbv_flow, :with_argyle_account) }

        it "redirects to the payment_details page" do
          post :create, params: { item_id: argyle_item_id }

          expect(response).to redirect_to(cbv_flow_payment_details_path(user: { account_id: cbv_flow.payroll_accounts.first.pinwheel_account_id }))
        end
      end

      context "if the payroll is not fully synced" do
        let(:cbv_flow) { create(:cbv_flow, :with_argyle_account, partially_synced: true) }

        it "redirects to the synchronizations page" do
          post :create, params: { item_id: argyle_item_id }

          expect(response).to redirect_to(cbv_flow_synchronizations_path(user: { account_id: cbv_flow.payroll_accounts.first.pinwheel_account_id }))
        end
      end
    end
  end
end
