require 'rails_helper'

RSpec.describe Aggregators::Sdk::ArgyleService, type: :service do
  include ArgyleApiHelper
  let(:service) { Aggregators::Sdk::ArgyleService.new("sandbox", "FAKE_API_KEY") }
  let(:account_id) { 'account123' }
  let(:user_id) { 'user123' }

  describe '#fetch_paystubs_api' do
    let(:requests) { WebMock::RequestRegistry.instance.requested_signatures.hash.keys }
    before do
      stub_request_paystubs_response("bob")
    end
    it 'calls the correct endpoint' do
      service.fetch_paystubs_api()
      expect(requests.first.uri.to_s).to include("/v2/paystubs")
    end
    it 'sets limit of 100 paystubs by default' do
      service.fetch_paystubs_api()
      expect(requests.first.uri.query).to include("limit=100")
    end
    it 'accepts param account' do
      service.fetch_paystubs_api(account: account_id)
      expect(requests.first.uri.query).to include("account=account123")
      expect(requests.first.uri.query).to include("limit=100")
    end

    it 'accepts param user' do
      service.fetch_paystubs_api(user: user_id)
      expect(requests.first.uri.query).to include("user=user123")
      expect(requests.first.uri.query).to include("limit=100")
    end

    it 'accepts multiple params' do
      service.fetch_paystubs_api(account: account_id, user: user_id, limit: 50)
      expect(requests.first.uri.query).to include("account=account123")
      expect(requests.first.uri.query).to include("user=user123")
      expect(requests.first.uri.query).to include("limit=50")
    end

    it 'returns a non-empty response' do
      response = service.fetch_paystubs_api()
      expect(response).not_to be_empty
      expect(response).to be_an_instance_of(Hash)
      expect(response).to have_key("results")
      expect(response).to have_key("next")
    end

    it 'raises Faraday::ServerError on 500 error' do
      stub_request(:get, "https://api-sandbox.argyle.com/v2/paystubs?limit=100")
      .to_return(status: 500, body: "", headers: {})

      expect { service.fetch_paystubs_api() }.to raise_error(Faraday::ServerError)
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
      expect { service.fetch_employments_api() }.to raise_error(ArgumentError)
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
end
