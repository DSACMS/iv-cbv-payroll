require 'rails_helper'

RSpec.describe PayrollAccount::Argyle, type: :model do
  let(:cbv_flow) { create(:cbv_flow) }
  let(:payroll_account) { create(:payroll_account, :argyle, cbv_flow: cbv_flow) }
  let(:synced_account) { create(:payroll_account, :argyle_fully_synced, cbv_flow: cbv_flow) }
  let(:partially_synced_account) { create(:payroll_account, :argyle_fully_synced, cbv_flow: cbv_flow, with_errored_jobs: [ 'paystubs' ]) }

  describe '.available_jobs' do
    it 'returns all job types from ArgyleService SUBSCRIBED_WEBHOOK_EVENTS' do
      # Get the job names directly from the ArgyleService
      expected_jobs = ArgyleService.get_supported_jobs
      expect(described_class.available_jobs).to match_array(expected_jobs)
    end
  end

  describe '#has_fully_synced?' do
    it 'returns false when no webhook events exist' do
      expect(payroll_account.has_fully_synced?).to be false
    end

    it 'returns true when all supported jobs have corresponding webhook events' do
      expect(synced_account.has_fully_synced?).to be true
    end
  end

  describe '#job_succeeded?' do
    it 'returns true when the job succeeded' do
      expect(synced_account.job_succeeded?('identity')).to be true
    end

    it 'returns false when the job failed' do
      expect(partially_synced_account.job_succeeded?('paystubs')).to be false
    end

    it 'returns false when the job is not supported' do
      account = create(:payroll_account, :argyle, cbv_flow: cbv_flow, supported_jobs: [ 'identity' ])
      expect(account.job_succeeded?('paystubs')).to be false
    end
  end

  describe '#synchronization_status' do
    it 'returns :unsupported when job is not supported' do
      account = create(:payroll_account, :argyle, cbv_flow: cbv_flow, supported_jobs: [ 'identity' ])
      expect(account.synchronization_status('paystubs')).to eq(:unsupported)
    end

    it 'returns :succeeded when job succeeded' do
      expect(synced_account.synchronization_status('identity')).to eq(:succeeded)
    end

    it 'returns :in_progress when job is pending' do
      expect(payroll_account.synchronization_status('paystubs')).to eq(:in_progress)
    end

    it 'returns :failed when job failed' do
      expect(partially_synced_account.synchronization_status('paystubs')).to eq(:failed)
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
