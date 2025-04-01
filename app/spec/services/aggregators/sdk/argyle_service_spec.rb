require 'rails_helper'

RSpec.describe Aggregators::Sdk::ArgyleService, type: :service do
  include ArgyleApiHelper

  attr_reader :test_fixture_directory

  let(:api_key_secret) { 'api_key_secret' }
  let(:webhook_secret) { 'test_webhook_secret' }
  let(:service) { Aggregators::Sdk::ArgyleService.new("sandbox", "FAKE_API_KEY", api_key_secret, webhook_secret) }
  let(:account_id) { 'account123' }
  let(:user_id) { 'user123' }

  before(:all) do
    @test_fixture_directory = 'argyle'
  end

  describe '#initialize' do
    context 'when the environment is sandbox' do
      let(:service) { Aggregators::Sdk::ArgyleService.new("sandbox") }

      it 'initializes with the correct environment' do
        expect(service.environment[:environment]).to eq("sandbox")
      end
    end

    context 'when the environment is production' do
      let(:service) { Aggregators::Sdk::ArgyleService.new("production") }

      it 'initializes with the correct environment' do
        expect(service.environment[:environment]).to eq("production")
      end
    end

    context 'when the environment is not provided' do
      let(:service) { Aggregators::Sdk::ArgyleService.new("sandbox") }

      it 'initializes with the correct environment' do
        expect(service.environment[:environment]).to eq("sandbox")
      end
    end

    context 'when environment variables are implied from the environment' do
      let(:implicitly_declared_service) { Aggregators::Sdk::ArgyleService.new("sandbox") }
      let(:env_implied_webhook_secret) { 'env_implied_webhook_secret' }

      around do | example |
        stub_environment_variable('ARGYLE_SANDBOX_WEBHOOK_SECRET', env_implied_webhook_secret, &example)
      end

      it 'initializes with the correct environment' do
        expect(implicitly_declared_service.environment[:environment]).to eq("sandbox")
        expect(implicitly_declared_service.environment[:webhook_secret]).to eq(env_implied_webhook_secret)
      end
    end

    context 'constructor args override environment variables' do
      around do | example |
        stub_environment_variable('ARGYLE_SANDBOX_WEBHOOK_SECRET', 'env_implied_webhook_secret', &example)
      end

      let(:explicitly_declared_service) { Aggregators::Sdk::ArgyleService.new("sandbox", "FAKE_API_KEY", api_key_secret, webhook_secret) }

      it 'initializes with the correct environment' do
        expect(explicitly_declared_service.environment[:environment]).to eq("sandbox")
        expect(explicitly_declared_service.environment[:webhook_secret]).to eq(webhook_secret)
      end
    end
  end

  describe '#fetch_identities_api' do
    let(:requests) { WebMock::RequestRegistry.instance.requested_signatures.hash.keys }
    before do
      stub_request_identities_response("bob")
    end

    it 'calls the correct endpoint' do
      service.fetch_identities_api
      expect(requests.first.uri.to_s).to include("/v2/identities")
    end

    it 'sets limit of 100 identities by default' do
      service.fetch_identities_api
      expect(requests.first.uri.query).to include("limit=10")
    end

    it 'accepts param account' do
      service.fetch_identities_api(account: account_id)
      expect(requests.first.uri.query).to include("account=account123")
      expect(requests.first.uri.query).to include("limit=10")
    end

    it 'accepts param user' do
      service.fetch_identities_api(user: user_id)
      expect(requests.first.uri.query).to include("user=user123")
      expect(requests.first.uri.query).to include("limit=10")
    end

    it 'accepts multiple params' do
      service.fetch_identities_api(account: account_id, user: user_id, limit: 50)
      expect(requests.first.uri.query).to include("account=account123")
      expect(requests.first.uri.query).to include("user=user123")
      expect(requests.first.uri.query).to include("limit=50")
    end

    it 'returns a non-empty response' do
      response = service.fetch_identities_api
      expect(response).not_to be_empty
      expect(response).to be_an_instance_of(Hash)
      expect(response).to have_key("results")
      expect(response).to have_key("next")
    end

    it 'raises Faraday::ServerError on 500 error' do
      stub_request(:get, "https://api-sandbox.argyle.com/v2/identities?limit=10")
      .to_return(status: 500, body: "", headers: {})

      expect { service.fetch_identities_api }.to raise_error(Faraday::ServerError)
    end
  end

  describe '#fetch_accounts_api' do
    let(:requests) { WebMock::RequestRegistry.instance.requested_signatures.hash.keys }
    before do
      stub_request_accounts_response("bob")
    end

    it 'calls the correct endpoint' do
      service.fetch_accounts_api
      expect(requests.first.uri.to_s).to include("/v2/accounts")
    end

    it 'sets limit of 10 accounts by default' do
      service.fetch_accounts_api
      expect(requests.first.uri.query).to include("limit=10")
    end

    it 'accepts param user' do
      service.fetch_accounts_api(user: user_id)
      expect(requests.first.uri.query).to include("user=user123")
      expect(requests.first.uri.query).to include("limit=10")
    end

    it 'accepts param ongoing_refresh_status' do
      service.fetch_accounts_api(ongoing_refresh_status: "enabled")
      expect(requests.first.uri.query).to include("ongoing_refresh_status=enabled")
      expect(requests.first.uri.query).to include("limit=10")
    end

    it 'rejects invalid ongoing_refresh_status' do
      expect { service.fetch_accounts_api(ongoing_refresh_status: "invalid_status") }.to raise_error(ArgumentError, "Invalid ongoing_refresh_status: invalid_status")
    end

    it 'accepts multiple params including ongoing_refresh_status' do
      service.fetch_accounts_api(user: user_id, ongoing_refresh_status: "enabled", limit: 50)
      expect(requests.first.uri.query).to include("user=user123")
      expect(requests.first.uri.query).to include("ongoing_refresh_status=enabled")
      expect(requests.first.uri.query).to include("limit=50")
    end

    it 'returns a non-empty response' do
      response = service.fetch_accounts_api
      expect(response).not_to be_empty
      expect(response).to be_an_instance_of(Hash)
      expect(response).to have_key("results")
      expect(response).to have_key("next")
    end

    it 'raises Faraday::ServerError on 500 error' do
      stub_request(:get, "https://api-sandbox.argyle.com/v2/accounts?limit=10")
      .to_return(status: 500, body: "", headers: {})

      expect { service.fetch_accounts_api }.to raise_error(Faraday::ServerError)
    end
  end

  describe '#fetch_paystubs_api' do
    let(:requests) { WebMock::RequestRegistry.instance.requested_signatures.hash.keys }
    before do
      stub_request_paystubs_response("bob")
    end
    it 'calls the correct endpoint' do
      service.fetch_paystubs_api
      expect(requests.first.uri.to_s).to include("/v2/paystubs")
    end
    it 'sets limit of 100 paystubs by default' do
      service.fetch_paystubs_api
      expect(requests.first.uri.query).to include("limit=200")
    end
    it 'accepts param account' do
      service.fetch_paystubs_api(account: account_id)
      expect(requests.first.uri.query).to include("account=account123")
      expect(requests.first.uri.query).to include("limit=200")
    end

    it 'accepts param user' do
      service.fetch_paystubs_api(user: user_id)
      expect(requests.first.uri.query).to include("user=user123")
      expect(requests.first.uri.query).to include("limit=200")
    end

    it 'accepts multiple params' do
      service.fetch_paystubs_api(account: account_id, user: user_id, limit: 50)
      expect(requests.first.uri.query).to include("account=account123")
      expect(requests.first.uri.query).to include("user=user123")
      expect(requests.first.uri.query).to include("limit=50")
    end

    it 'returns a non-empty response' do
      response = service.fetch_paystubs_api
      expect(response).not_to be_empty
      expect(response).to be_an_instance_of(Hash)
      expect(response).to have_key("results")
      expect(response).to have_key("next")
    end

    it 'raises Faraday::ServerError on 500 error' do
      stub_request(:get, "https://api-sandbox.argyle.com/v2/paystubs?limit=200")
      .to_return(status: 500, body: "", headers: {})

      expect { service.fetch_paystubs_api }.to raise_error(Faraday::ServerError)
    end

    it 'raises Pagination not implemented error if a new page is found.' do
      stub_request(:get, "https://api-sandbox.argyle.com/v2/paystubs?limit=200")
      .to_return(status: 200, body: { "next": "https://next-page-url" }.to_json, headers: {})

      expect { service.fetch_paystubs_api }.to raise_error("Pagination not implemented")
    end
  end

  describe '#fetch_employments_api' do
    before do
      stub_request_employments_response("bob")
    end

    it 'accepts param account' do
      service.fetch_employments_api(account: account_id)
      assert_requested :get, "https://api-sandbox.argyle.com/v2/employments?account=account123"
    end

    it 'accepts param user' do
      service.fetch_employments_api(user: user_id)
      assert_requested :get, "https://api-sandbox.argyle.com/v2/employments?user=user123"
    end

    it 'rejects empty params' do
      expect { service.fetch_employments_api }.to raise_error(ArgumentError)
    end

    it 'returns a non-empty response' do
      response = service.fetch_employments_api(account: account_id)
      expect(response).not_to be_empty
    end

    it 'raises Faraday::ServerError on 500 error' do
      stub_request(:get, "https://api-sandbox.argyle.com/v2/employments?account=account123")
      .to_return(status: 500, body: "", headers: {})

      expect { service.fetch_employments_api(account: account_id) }.to raise_error(Faraday::ServerError)
    end
  end

  describe '#create_user' do
    context 'with external_id' do
      let(:external_id) { 'external_123' }

      it 'makes a POST request with external_id' do
        expect(service).to receive(:make_request)
                             .with(:post, 'users', { external_id: external_id })
        service.create_user(external_id)
      end
    end

    context 'without external_id' do
      it 'makes a POST request without external_id' do
        expect(service).to receive(:make_request)
                             .with(:post, 'users', {})
        service.create_user
      end
    end
  end

  describe '#get_webhook_subscriptions' do
    it 'makes a GET request to webhooks endpoint' do
      expect(service).to receive(:make_request)
                           .with(:get, 'webhooks')
      service.get_webhook_subscriptions
    end
  end

  describe '#create_webhook_subscription' do
    let(:events) { [ 'users.fully_synced' ] }
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
      expect(service).to receive(:make_request).with(:post, 'webhooks', expected_payload)
      service.create_webhook_subscription(events, url, name)
    end
  end

  describe '#delete_webhook_subscription' do
    let(:webhook_id) { '123' }

    it 'makes a DELETE request to remove webhook subscription' do
      expect(service).to receive(:make_request)
                           .with(:delete, "webhooks/#{webhook_id}")
      service.delete_webhook_subscription(webhook_id)
    end
  end
end
