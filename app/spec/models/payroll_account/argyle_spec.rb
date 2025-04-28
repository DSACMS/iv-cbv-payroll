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

    describe '#necessary_jobs_succeeded?' do
      let(:account) { create(:payroll_account, :argyle, cbv_flow: cbv_flow) }

      it 'returns true when paystubs succeeded' do
        create(:webhook_event, payroll_account: account, event_name: 'paystubs.partially_synced', event_outcome: 'success')

        expect(account.necessary_jobs_succeeded?).to be true
      end

      it 'returns true when gigs succeeded' do
        create(:webhook_event, payroll_account: account, event_name: 'gigs.partially_synced', event_outcome: 'success')

        expect(account.necessary_jobs_succeeded?).to be true
      end

      it 'returns false when neither paystubs nor gigs succeeded' do
        expect(payroll_account.necessary_jobs_succeeded?).to be false
      end

      context "when the accounts job fails" do
        before do
          create(:webhook_event, payroll_account: account, event_name: "accounts.updated", event_outcome: "error")
        end

        it "returns false" do
          expect(payroll_account.necessary_jobs_succeeded?).to be false
        end
      end
    end
  end
end
