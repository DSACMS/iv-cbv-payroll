require 'rails_helper'

RSpec.describe PayrollAccount::Pinwheel, type: :model do
  let(:account_id) { SecureRandom.uuid }
  let(:supported_jobs) { %w[income paystubs employment] }
  let!(:cbv_flow) { create(:cbv_flow, :invited, pinwheel_token_id: "abc-def-ghi", client_agency_id: "sandbox") }
  let!(:payroll_account) do
    create(:payroll_account, cbv_flow: cbv_flow, pinwheel_account_id: account_id, supported_jobs: supported_jobs)
  end

  def create_webhook_events(income_success: true, employment_success: true, paystubs_success: true, income_errored: false, shifts_success: false)
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

    if shifts_success
      create(:webhook_event, event_name: "shifts.added", payroll_account: payroll_account)
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

    context "when shifts is supported" do
      let(:supported_jobs) { super() + %w[shifts] }

      it "is false before shifts.added webhook has arrived" do
        expect(payroll_account.has_fully_synced?).to eq(false)
      end

      context "after the shifts.added webhook arrives" do
        before do
          create_webhook_events(shifts_success: true)
        end

        it "is true" do
          expect(payroll_account.has_fully_synced?).to eq(true)
        end
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

  describe "#job_status" do
    context "when the job's status is succeeded" do
      before do
        create_webhook_events
      end

      it "returns succeeded" do
        expect(payroll_account.job_status('income')).to eq(:succeeded)
      end
    end

    context "when the job's status is failed" do
      before do
        create_webhook_events(income_success: false, income_errored: true)
      end

      it "returns failed" do
        expect(payroll_account.job_status('income')).to eq(:failed)
      end
    end

    context "when the job has no events (either successful or errored)" do
      it "returns in_progress" do
        expect(payroll_account.job_status('income')).to eq(:in_progress)
      end
    end

    context "when status is unsupported" do
      let(:supported_jobs) { super() - [ "income" ] }

      it "returns unsupported" do
        expect(payroll_account.job_status('income')).to eq(:unsupported)
      end
    end
  end

  describe "#necessary_jobs_succeeded?" do
    let!(:payroll_account) do
       create(:payroll_account, :pinwheel_fully_synced, with_errored_jobs: %w[income])
     end
    it "supports a case where they have no reported income so long as we can scan their identities for unemployment" do
         expect(payroll_account.necessary_jobs_succeeded?).to eq(true)
       end
  end

  describe "#redact!" do
    it "updates the redacted_at timestamp" do
      expect { payroll_account.redact! }
        .to change { payroll_account.reload.redacted_at }
        .from(nil).to(within(1.second).of(Time.now))
    end
  end
end
