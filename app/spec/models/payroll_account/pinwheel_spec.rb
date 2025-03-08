require 'rails_helper'

RSpec.describe PayrollAccount::Pinwheel, type: :model do
  let(:account_id) { SecureRandom.uuid }
  let(:supported_jobs) { %w[income paystubs employment] }
  let!(:cbv_flow) { create(:cbv_flow, pinwheel_token_id: "abc-def-ghi", client_agency_id: "sandbox") }
  let!(:payroll_account) do
    create(:payroll_account, cbv_flow: cbv_flow, pinwheel_account_id: account_id, supported_jobs: supported_jobs)
  end

  def create_webhook_events(income_success: true, employment_success: true, paystubs_success: true, income_errored: false)
    if income_success
      create(:webhook_event, event_name: "income.added", payroll_account: payroll_account)
    elsif income_errored
      create(:webhook_event, event_name: "income.added", event_outcome: "error", payroll_account: payroll_account)
    end

    if employment_success
      create(:webhook_event, event_name: "employment.added", payroll_account: payroll_account)
    end

    if paystubs_success
      create(:webhook_event, event_name: "paystubs.fully_synced", payroll_account: payroll_account)
    end
  end

  describe "#has_fully_synced?" do
    context "when all supported_jobs have synced" do
      before do
        create_webhook_events
      end

      it "returns true" do
        expect(payroll_account.has_fully_synced?).to be_truthy
      end
    end

    context "when income has not synced" do
      before do
        create_webhook_events(income_success: false)
      end

      it "returns false when income_synced_at is nil" do
        expect(payroll_account.has_fully_synced?).to be_falsey
      end
    end

    context "when income is not supported" do
      let(:supported_jobs) { %w[paystubs employment] }

      before do
        create_webhook_events(income_success: false)
      end

      it "returns true when income_synced_at is nil" do
        expect(payroll_account.has_fully_synced?).to be_truthy
      end
    end
  end

  describe "#job_succeeded?" do
    context "when job is supported" do
      it "returns false when income is supported but not yet synced" do
        expect(payroll_account.job_succeeded?('income')).to be_falsey
      end

      context "after the job has succeeded" do
        before do
          create_webhook_events
        end

        it "returns true when income is supported and it succeeded" do
          expect(payroll_account.job_succeeded?('income')).to be_truthy
        end
      end
    end

    context "when job is supported but it errored out" do
      before do
        create_webhook_events(income_success: false, income_errored: true)
      end

      it "returns false when income is supported but it errored out" do
        expect(payroll_account.job_succeeded?('income')).to be_falsey
      end
    end

    context "when job is unsupported" do
      let(:supported_jobs) { super() - [ "income" ] }

      it "returns false" do
        expect(payroll_account.job_succeeded?('income')).to be_falsey
      end
    end
  end

  describe "#synchronization_status" do
    context "when the job's status is succeeded" do
      before do
        create_webhook_events
      end

      it "returns succeeded" do
        expect(payroll_account.synchronization_status('income')).to eq(:succeeded)
      end
    end

    context "when the job's status is failed" do
      before do
        create_webhook_events(income_success: false, income_errored: true)
      end

      it "returns failed" do
        expect(payroll_account.synchronization_status('income')).to eq(:failed)
      end
    end

    context "when the job has no events (either successful or errored)" do
      it "returns in_progress" do
        expect(payroll_account.synchronization_status('income')).to eq(:in_progress)
      end
    end

    context "when status is unsupported" do
      let(:supported_jobs) { super() - [ "income" ] }

      it "returns unsupported" do
        expect(payroll_account.synchronization_status('income')).to eq(:unsupported)
      end
    end
  end
end
