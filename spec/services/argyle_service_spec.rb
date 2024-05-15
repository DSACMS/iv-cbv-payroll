require 'rails_helper'
require 'support/account_connected_webhook_stub'
require 'support/payroll_documents_response_stub'

RSpec.describe ArgyleService, type: :service do
  include ArgyleApiHelper
  let(:service) { ArgyleService.new }
  let(:user_id) { 'abc123' }

  describe '#fetch_items' do
    before do
      stub_request_items_response
    end

    it 'returns a non-empty response' do
      response = service.fetch_items({ q: 'test' })
      expect(response).not_to be_empty
    end
  end

  describe '#fetch_paystubs' do
    before do
      stub_request_paystubs_response
    end

    it 'returns a non-empty response' do
      service = ArgyleService.new
      response = service.fetch_paystubs({ user: user_id })
      expect(response).not_to be_empty
    end
  end

  describe '#create_user' do
    before do
      stub_create_user_response(user_id: user_id)
    end

    it 'returns a user token' do
      response = service.create_user
      expect(response['user_token']).to eq(user_id)
    end
  end

  describe '#refresh_user_token' do
    before do
      stub_refresh_user_token_response
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
