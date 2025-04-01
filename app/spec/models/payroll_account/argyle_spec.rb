require 'rails_helper'

RSpec.describe PayrollAccount::Argyle, type: :model do
    let(:cbv_flow) { create(:cbv_flow) }
    let(:payroll_account) { create(:payroll_account, :argyle, cbv_flow: cbv_flow) }
    let(:synced_account) { create(:payroll_account, :argyle_fully_synced, cbv_flow: cbv_flow) }

    describe '.available_jobs' do
      it 'returns all job types from ArgyleService SUBSCRIBED_WEBHOOK_EVENTS' do
        expected_jobs = Webhooks::Argyle.get_supported_jobs
        expect(described_class.available_jobs).to match_array(expected_jobs)
      end
    end

    describe '#has_fully_synced?' do
        it 'returns false when no webhook events exist' do
          expect(payroll_account.has_fully_synced?).to be false
        end

        it 'returns true when all supported jobs have corresponding webhook events' do
        expect(synced_account.has_fully_synced?).to be true
        expect(synced_account.webhook_events.count).to eq(Webhooks::Argyle.get_supported_jobs.count)
      end

        describe '#job_succeeded?' do
          it 'returns true when the job succeeded' do
            expect(synced_account.job_succeeded?('identity')).to be true
          end
        end

        describe '#has_required_data?' do
          it 'returns true when paystubs succeeded' do
            account = create(:payroll_account, :argyle, cbv_flow: cbv_flow)
            create(:webhook_event, payroll_account: account, event_name: 'paystubs.fully_synced', event_outcome: 'success')

            expect(account.has_required_data?).to be true
          end

          it 'returns true when gigs succeeded' do
            account = create(:payroll_account, :argyle, cbv_flow: cbv_flow)
            create(:webhook_event, payroll_account: account, event_name: 'gigs.fully_synced', event_outcome: 'success')

            expect(account.has_required_data?).to be true
          end

          it 'returns false when neither paystubs nor gigs succeeded' do
            expect(payroll_account.has_required_data?).to be false
          end
        end
      end
  end
