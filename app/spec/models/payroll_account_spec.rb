require 'rails_helper'

RSpec.describe PayrollAccount, type: :model do
  let(:account_id) { SecureRandom.uuid }
  let(:supported_jobs) { %w[income paystubs employment] }
  let!(:cbv_flow) { create(:cbv_flow, pinwheel_token_id: "abc-def-ghi", client_agency_id: "sandbox") }
  let!(:payroll_account) do
    create(:payroll_account,
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
        payroll_account.update!(income_synced_at: Time.current)
        expect(payroll_account.has_fully_synced?).to be_truthy
      end

      context "when income_synced_at is nil" do
        let(:income_synced_at) { nil }

        it "returns false when income_synced_at is nil" do
          expect(payroll_account.has_fully_synced?).to be_falsey
        end
      end
    end

    context "when income is not supported" do
      let(:supported_jobs) { %w[paystubs employment] }
      let(:income_synced_at) { nil }

      it "returns true when income_synced_at is nil" do
        expect(payroll_account.has_fully_synced?).to be_truthy
      end
    end
  end

  describe "#job_succeeded?" do
    context "when job is supported" do
      it "returns false when income is supported but not yet synced" do
        payroll_account.update!(income_synced_at: nil)
        expect(payroll_account.job_succeeded?('income')).to be_falsey
      end

      it "returns true when income is supported and it succeeded" do
        payroll_account.update!(income_synced_at: Time.current)
        expect(payroll_account.job_succeeded?('income')).to be_truthy
      end
    end

    context "when job is supported but it errored out" do
      it "returns false when income is supported but it errored out" do
        payroll_account.update!(income_synced_at: Time.current)
        payroll_account.update!(income_errored_at: Time.current)
        expect(payroll_account.job_succeeded?('income')).to be_falsey
      end

      it "returns false when employment is supported but it errored out" do
        payroll_account.update!(employment_synced_at: Time.current)
        payroll_account.update!(employment_errored_at: Time.current)
        expect(payroll_account.job_succeeded?('employment')).to be_falsey
      end
    end
  end

  describe "#synchronization_status" do
    context "when status is succeeded" do
      it "returns succeeded" do
        payroll_account.update!(income_synced_at: Time.current)
        expect(payroll_account.synchronization_status('income')).to eq(:succeeded)
      end
    end

    context "when status is failed" do
      it "returns failed" do
        payroll_account.update!(income_synced_at: Time.current, income_errored_at: Time.current)
        expect(payroll_account.synchronization_status('income')).to eq(:failed)
      end
    end

    context "when status is in_progress" do
      it "returns in_progress" do
        payroll_account.update!(income_synced_at: nil, income_errored_at: nil)
        expect(payroll_account.synchronization_status('income')).to eq(:in_progress)
      end
    end

    context "when status is unsupported" do
      it "returns unsupported" do
        payroll_account.update!(supported_jobs: supported_jobs.reject { |job| job == 'income' })
        expect(payroll_account.synchronization_status('income')).to eq(:unsupported)
      end
    end
  end
end
