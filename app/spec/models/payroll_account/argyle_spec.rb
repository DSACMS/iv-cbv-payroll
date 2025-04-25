require 'rails_helper'

RSpec.describe PayrollAccount::Argyle, type: :model do
  let(:cbv_flow) { create(:cbv_flow) }
  let(:payroll_account) { create(:payroll_account, :argyle, cbv_flow: cbv_flow) }
  let(:synced_account) { create(:payroll_account, :argyle_fully_synced, cbv_flow: cbv_flow) }

  it "has a synchronization_status of 'unknown' by default" do
    payroll_account = cbv_flow.payroll_accounts.create
    expect(payroll_account.sync_unknown?).to eq(true)
  end

  describe '#has_fully_synced?' do
    it 'returns false when no webhook events exist' do
      expect(payroll_account.has_fully_synced?).to be false
    end

    it 'returns true when all supported jobs have corresponding webhook events' do
      expect(synced_account.has_fully_synced?).to be true
      expect(synced_account.webhook_events.count).to eq(Aggregators::Webhooks::Argyle.get_supported_jobs.count)
    end

    describe '#job_succeeded?' do
      it 'returns true when the job succeeded' do
        expect(synced_account.job_succeeded?('identity')).to be true
      end
    end

    describe "#necessary_jobs_succeeded?" do
      let(:account) { create(:payroll_account, :argyle, cbv_flow: cbv_flow) }

      it "returns false when no webhooks have returned" do
        expect(payroll_account.necessary_jobs_succeeded?).to be false
      end

      it "returns false when only paystubs and gigs have been received" do
        create(:webhook_event, payroll_account: account, event_name: "paystubs.partially_synced", event_outcome: "success")
        create(:webhook_event, payroll_account: account, event_name: "gigs.partially_synced", event_outcome: "success")

        expect(payroll_account.necessary_jobs_succeeded?).to be false
      end

      context "when accounts has succeeded" do
        before do
          create(:webhook_event, payroll_account: account, event_name: "accounts.connected", event_outcome: "success")
        end

        it "returns true when paystubs succeeded" do
          create(:webhook_event, payroll_account: account, event_name: "paystubs.partially_synced", event_outcome: "success")

          expect(account.necessary_jobs_succeeded?).to be true
        end

        it "returns true when gigs succeeded" do
          create(:webhook_event, payroll_account: account, event_name: "gigs.partially_synced", event_outcome: "success")

          expect(account.necessary_jobs_succeeded?).to be true
        end

        it "returns true when paystubs.fully_synced has been received" do
          # this is the case for gig jobs where paystubs.partially_synced may
          # never be fetched
          create(:webhook_event, payroll_account: account, event_name: "paystubs.fully_synced", event_outcome: "success")

          expect(account.necessary_jobs_succeeded?).to be true
        end

        it "returns true when gigs.fully_synced has been received" do
          # this is the case for W2 jobs where gigs.partially_synced may
          # never be fetched
          create(:webhook_event, payroll_account: account, event_name: "gigs.fully_synced", event_outcome: "success")

          expect(account.necessary_jobs_succeeded?).to be true
        end

        it "returns false when an errored accounts.updated is received later" do
          create(:webhook_event, payroll_account: account, event_name: "accounts.updated", event_outcome: "error")

          expect(payroll_account.necessary_jobs_succeeded?).to be false
        end
      end
    end
  end
end
