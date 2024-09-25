require "rails_helper"

RSpec.describe Webhooks::Pinwheel::EventsController do
  let(:valid_params) do
    {
      "event" => event_name,
      "payload" => payload
    }
  end
  let(:request_headers) do
    {
      "X-Pinwheel-Signature" => "v2=test-signature",
      "X-Timestamp" => "test-timestamp"
    }
  end
  let(:cbv_flow) { create(:cbv_flow, site_id: "sandbox") }
  let(:account_id) { "00000000-0000-0000-0000-000000000000" }

  before do
    request.headers.merge!(request_headers)
    allow_any_instance_of(PinwheelService).to receive(:generate_signature_digest)
      .with("test-timestamp", anything)
      .and_return("v2=test-signature")
  end

  describe "#create" do
    let(:supported_jobs) { [ "paystubs", "identity", "income", "employment" ] }

    before do
      allow_any_instance_of(PinwheelService).to receive(:fetch_platform)
        .with(platform_id: "fake-platform-id")
        .and_return("data" => { "supported_jobs" => supported_jobs })
    end

    context "for an 'account.added' event" do
      let(:event_name) { "account.added" }
      let(:payload) do
        {
          "platform_id" => "fake-platform-id",
          "end_user_id" => cbv_flow.pinwheel_end_user_id,
          "account_id" => account_id
        }
      end

      it "creates a PinwheelAccount object" do
        expect do
          post :create, params: valid_params
        end.to change(PinwheelAccount, :count).by(1)

        pinwheel_account = PinwheelAccount.last
        expect(pinwheel_account).to have_attributes(
          cbv_flow_id: cbv_flow.id,
          supported_jobs: supported_jobs,
          pinwheel_account_id: account_id
        )
      end

      context "when the webhook signature is incorrect" do
        before do
          request.headers["X-Pinwheel-Signature"] = "wrong-signature"
        end

        it "discards the webhook" do
          expect do
            post :create, params: valid_params
          end.not_to change(PinwheelAccount, :count)

          expect(response).to be_unauthorized
        end
      end
    end

    context "for an 'paystubs.fully_synced' event" do
      let(:event_name) { "paystubs.fully_synced" }
      let(:payload) do
        {
          "account_id" => account_id,
          "end_user_id" => cbv_flow.pinwheel_end_user_id,
          "outcome" => "success"
        }
      end
      let(:pinwheel_account) { PinwheelAccount.create!(cbv_flow: cbv_flow, supported_jobs: supported_jobs, pinwheel_account_id: account_id) }

      it "updates the PinwheelAccount object with the current timestamp" do
        expect { post :create, params: valid_params }
          .to change { pinwheel_account.reload.paystubs_synced_at }
          .from(nil)
          .to(within(1.second).of(Time.now))
      end
    end
  end
end
