require 'rails_helper'
require 'support/account_connected_webhook_stub'
require 'support/payroll_documents_response_stub'

RSpec.describe ArgyleService, type: :service do
  let(:service) { ArgyleService.new }
  let(:user_id) { 'user_id' }

  describe '#fetch_items' do
    before do
      stub_request(:get, ArgyleService::ITEMS_ENDPOINT)
        .with(query: { q: 'test' })
        .to_return(status: 200, body: '{ "results": [{ "id": "12345" }] }')
    end

    it 'returns a non-empty response' do
      response = service.fetch_items({ q: 'test' })
      expect(response).not_to be_empty
      expect(response["results"].first['id']).to eq("12345")
    end
  end

  describe '#fetch_paystubs' do
    before do
      stub_request(:get, ArgyleService::PAYSTUBS_ENDPOINT)
        .with(query: { user: user_id })
        .to_return(status: 200, body: '{ "results": [{ "id": "12345" }] }')
    end

    it 'returns a non-empty response' do
      service = ArgyleService.new
      response = service.fetch_paystubs({ user: user_id })
      expect(response).not_to be_empty
      expect(response["results"].first['id']).to eq("12345")
    end
  end

  describe '#create_user' do
    before do
      stub_request(:post, ArgyleService::USERS_ENDPOINT)
        .to_return(status: 200, body: '{"user_token": "abc123"}')
    end

    it 'returns a user token' do
      response = service.create_user
      expect(response['user_token']).to eq("abc123")
    end
  end

  describe '#refresh_user_token' do
    before do
      stub_request(:post, ArgyleService::USER_TOKENS_ENDPOINT)
        .to_return(status: 200, body: '{"user_token": "abc123"}')
    end

    it 'returns a refreshed user token' do
      service = ArgyleService.new
      response = service.refresh_user_token(user_id)
      expect(response['user_token']).to eq("abc123")
    end
  end

  describe 'Error handling' do
    skip 'raises an error when the API key is blank' do
    end

    skip 'raises an error when receiving a 400' do
    end
  end
end
