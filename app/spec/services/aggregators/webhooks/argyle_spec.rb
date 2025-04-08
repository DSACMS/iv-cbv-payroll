require 'rails_helper'

RSpec.describe Aggregators::Webhooks::Argyle, type: :service do
  describe '#generate_signature_digest' do
    let(:payload) { '{"event": "test"}' }
    let(:webhook_secret) { 'test_webhook_secret' }

    it 'generates correct HMAC SHA-512 digest' do
      # Use the real implementation to keep it simple
      expected_digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha512"), webhook_secret, payload)
      expect(described_class.generate_signature_digest(payload, webhook_secret)).to eq(expected_digest)
    end
  end

  describe '.get_webhook_events' do
    it 'returns array of supported webhook events' do
      expect(described_class.get_webhook_events).to eq(described_class::SUBSCRIBED_WEBHOOK_EVENTS.keys)
    end
  end

  describe '.get_supported_jobs' do
    it 'returns array of unique supported jobs' do
      expected_jobs = described_class::SUBSCRIBED_WEBHOOK_EVENTS.values
        .map { |event| event[:job] }
        .flatten
        .compact
        .uniq
      expect(described_class.get_supported_jobs).to eq(expected_jobs)
    end
  end

  describe '.get_webhook_event_outcome' do
    let(:event) { 'users.fully_synced' }

    it 'returns status for given event' do
      expect(described_class.get_webhook_event_outcome(event))
        .to eq(described_class::SUBSCRIBED_WEBHOOK_EVENTS[event][:status])
    end
  end

  describe '.get_webhook_event_jobs' do
    let(:event) { 'users.fully_synced' }

    it 'returns jobs for given event' do
      expect(described_class.get_webhook_event_jobs(event))
        .to eq(described_class::SUBSCRIBED_WEBHOOK_EVENTS[event][:job])
    end
  end
end
