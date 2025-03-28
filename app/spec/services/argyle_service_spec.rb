require 'rails_helper'

RSpec.describe ArgyleService, type: :service do
  include ArgyleApiHelper
  include TestHelpers

  let(:api_key_id) { 'test_key_id' }
  let(:api_key_secret) { 'test_key_secret' }
  let(:environment) { 'sandbox' }
  let(:webhook_secret) { 'fooo' }
  let(:base_url) { 'https://api-sandbox.argyle.com/v2' }

  let(:argyle_service) do
    # Stub Faraday at instance level to avoid HTTP requests
    allow(Faraday).to receive(:new).and_return(double(
      get: double(body: {}),
      post: double(body: {}),
      delete: double(body: {})
    ).as_null_object)

    service = ArgyleService.new(environment, api_key_id, api_key_secret, webhook_secret)
    # Stub make_request method to avoid actual API calls
    allow(service).to receive(:make_request).and_return({})
    service
  end

  describe '#items' do
    let(:query) { 'search_term' }

    it 'makes a GET request to items endpoint with correct parameters' do
      expect(argyle_service).to receive(:make_request).with(:get, 'items', { q: query })
      argyle_service.items(query)
    end
  end

  describe '#create_user' do
    context 'with external_id' do
      let(:external_id) { 'external_123' }

      it 'makes a POST request with external_id' do
        expect(argyle_service).to receive(:make_request)
          .with(:post, 'users', { external_id: external_id })
        argyle_service.create_user(external_id)
      end
    end

    context 'without external_id' do
      it 'makes a POST request without external_id' do
        expect(argyle_service).to receive(:make_request)
          .with(:post, 'users', {})
        argyle_service.create_user
      end
    end
  end

  describe '#get_webhook_subscriptions' do
    it 'makes a GET request to webhooks endpoint' do
      expect(argyle_service).to receive(:make_request)
        .with(:get, 'webhooks')
      argyle_service.get_webhook_subscriptions
    end
  end

  describe '#create_webhook_subscription' do
    let(:events) { ['users.fully_synced'] }
    let(:url) { 'https://example.com/webhook' }
    let(:name) { 'Test Webhook' }
    let(:expected_payload) do
      {
        events: events,
        name: name,
        url: url,
        secret: webhook_secret
      }
    end

    it 'makes a POST request to create webhook subscription with correct payload' do
      expect(argyle_service).to receive(:make_request).with(:post, 'webhooks', expected_payload)
      argyle_service.create_webhook_subscription(events, url, name)
    end
  end

  describe '#delete_webhook_subscription' do
    let(:webhook_id) { '123' }

    it 'makes a DELETE request to remove webhook subscription' do
      expect(argyle_service).to receive(:make_request)
        .with(:delete, "webhooks/#{webhook_id}")
      argyle_service.delete_webhook_subscription(webhook_id)
    end
  end

  describe '#generate_signature_digest' do
    let(:payload) { '{"event": "test"}' }

    it 'generates correct HMAC SHA-512 digest' do
      # Use the real implementation to keep it simple
      expected_digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha512"), webhook_secret, payload)
      expect(argyle_service.generate_signature_digest(payload)).to eq(expected_digest)
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
