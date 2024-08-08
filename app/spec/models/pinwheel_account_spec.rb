require 'rails_helper'

RSpec.describe PinwheelAccount, type: :model do
  let(:account_id) { SecureRandom.uuid }
  let(:supported_jobs) { %w[income paystubs employment] }
  let!(:cbv_flow) { CbvFlow.create!(case_number: "ABC1234", pinwheel_token_id: "abc-def-ghi", site_id: "sandbox") }
  let!(:pinwheel_account) do
    PinwheelAccount.create!(
      cbv_flow: cbv_flow,
      pinwheel_account_id: account_id,
      supported_jobs: supported_jobs,
      paystubs_synced_at: paystubs_synced_at,
      income_synced_at: income_synced_at,
      employment_synced_at: employment_synced_at
    )
  end
  let(:paystubs_synced_at) { Time.current }
  let(:income_synced_at) { Time.current }
  let(:employment_synced_at) { Time.current }

  describe "#has_fully_synced?" do
    context "when income is supported" do
      it "returns true when all are synced" do
        pinwheel_account.update!(income_synced_at: Time.current)
        expect(pinwheel_account.has_fully_synced?).to be_truthy
      end

      context "when income_synced_at is nil" do
        let(:income_synced_at) { nil }

        it "returns false when income_synced_at is nil" do
          expect(pinwheel_account.has_fully_synced?).to be_falsey
        end
      end
    end

    context "when income is not supported" do
      let(:supported_jobs) { %w[paystubs employment] }
      let(:income_synced_at) { nil }

      it "returns true when income_synced_at is nil" do
        expect(pinwheel_account.has_fully_synced?).to be_truthy
      end
    end
  end
end
