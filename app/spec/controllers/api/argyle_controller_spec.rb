require "rails_helper"

RSpec.describe Api::ArgyleController do
  include ArgyleApiHelper

  describe "#create" do
    let(:cbv_flow) { create(:cbv_flow) }
    # get the argyle user id and item e.g. payroll/provider to include in the fetch_user_api_response stub
    let(:argyle_user_id) { argyle_load_relative_json_file('', 'response_create_user.json')["id"] }
    let(:argyle_item_id) { argyle_user_property_for("bob", "user", "items_connected").first }
    let(:argyle_account_id) { argyle_user_property_for("bob", "user", "id") }
    let(:valid_params) { { item_id: argyle_item_id } }

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when the CbvFlow does not have an argyle_user_id" do
      before do
        stub_create_user_response
        argyle_stub_request_empty_accounts_response
      end

      it "creates a user with Argyle, returning its token" do
        post :create, params: valid_params

        expect(JSON.parse(response.body))
          .to include("user" => { "user_token" => be_a(String) })
      end

      it "tracks a Mixpanel event" do
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantBeganLinkingEmployer", anything, hash_including(
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
          ))
        post :create, params: valid_params
      end

      it "includes isSandbox flag in response" do
        argyle = double('argyle',
          create_user: { "id" => "some-user-id", "user_token" => "some-token" },
          fetch_accounts_api: { "results" => [] }
        )

        allow(CbvFlow).to receive(:find).and_return(cbv_flow)
        allow(controller).to receive(:argyle_for).and_return(argyle)

        post :create, params: valid_params

        expect(JSON.parse(response.body)["isSandbox"]).to eq(true)
      end
    end

    context "when the CbvFlow already has an argyle_user_id" do
      let(:cbv_flow) { create(:cbv_flow, argyle_user_id: "foo-bar-baz") }

      before do
        stub_create_user_token_response
        argyle_stub_request_accounts_response('bob')
      end

      it "creates a token for the existing Argyle user" do
        expect_any_instance_of(Aggregators::Sdk::ArgyleService)
          .to receive(:create_user_token)
          .with(cbv_flow.argyle_user_id)
          .and_return("user_token" => "fake-user-token")

        post :create, params: valid_params

        expect(JSON.parse(response.body))
          .to include("user" => { "user_token" => "fake-user-token" })
      end
    end

    context "when called without an item ID" do
      it "renders an error" do
        post :create, params: {}
        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)).to include("status" => "error")
      end
    end

    context "when the payroll account or employer has already been linked" do
      let(:cbv_flow) { create(:cbv_flow, argyle_user_id: argyle_user_id) }

      before do
        stub_create_user_response
        stub_create_user_token_response

        allow_any_instance_of(Aggregators::Sdk::ArgyleService)
          .to receive(:fetch_accounts_api)
          .with(user: argyle_user_id, item: argyle_item_id)
          .and_return({ "results" => [ { "id" => argyle_account_id, "item" => argyle_item_id } ] })
      end

      context "if the payroll account is fully synced" do
        let(:cbv_flow) { create(:cbv_flow, :with_argyle_account, argyle_user_id: argyle_user_id) }

        before do
          # Update the pinwheel_account_id to match the one returned by fetch_accounts_api
          cbv_flow.payroll_accounts.first.update(pinwheel_account_id: argyle_account_id)
        end

        it "redirects to the payment_details page" do
          post :create, params: valid_params

          expect(response).to redirect_to(cbv_flow_payment_details_path(user: { account_id: cbv_flow.payroll_accounts.first.pinwheel_account_id }))
        end
      end

      context "if the payroll sync is in progress" do
        let(:cbv_flow) { create(:cbv_flow, :with_argyle_account, argyle_user_id: argyle_user_id, sync_in_progress: true) }
        let(:payroll_account) { cbv_flow.payroll_accounts.first }

        before do
          # Update the pinwheel_account_id to match the one returned by fetch_accounts_api
          payroll_account.update(pinwheel_account_id: argyle_account_id)
        end

        it "returns the token for the existing argyle user without redirecting" do
          post :create, params: valid_params

          expect(JSON.parse(response.body))
            .to include("user" => { "user_token" => be_a(String) })
        end

        context "after receiving the accounts.connected webhook" do
          before do
            create(:webhook_event, payroll_account: payroll_account, event_name: "accounts.connected")
          end

          it "redirects to the synchronizations page" do
            post :create, params: valid_params

            expect(response).to redirect_to(cbv_flow_synchronizations_path(user: { account_id: payroll_account.pinwheel_account_id }))
          end
        end
      end

      context "when multiple accounts exist but only one is related to the item" do
        let(:cbv_flow) { create(:cbv_flow, :with_argyle_account, argyle_user_id: argyle_user_id) }
        let(:other_argyle_account_id) { "acc_987654321" }

        before do
          # Create a second payroll account with a different account ID
          create(:payroll_account, :argyle, cbv_flow: cbv_flow, pinwheel_account_id: other_argyle_account_id)

          # Make sure the first account ID matches what's returned by the API
          cbv_flow.payroll_accounts.first.update(pinwheel_account_id: argyle_account_id)
        end

        it "finds the correct payroll account for the item and redirects accordingly" do
          post :create, params: valid_params

          expect(response).to redirect_to(cbv_flow_payment_details_path(user: { account_id: argyle_account_id }))
        end
      end
    end
  end
end
