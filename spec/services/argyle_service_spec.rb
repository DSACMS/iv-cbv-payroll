require 'rails_helper'
require 'support/account_connected_webhook_stub'
require 'support/payroll_documents_response_stub'

RSpec.describe ArgyleService, type: :service do
  let(:service) { ArgyleService.new }
  let(:account_id) { 'account_id' }
  let(:user_id) { 'user_id' }
  let(:fake_response) { instance_double(Faraday::Response, body: payroll_documents_response_stub) }

  describe 'Initialization' do
    it 'has a default API endpoint pointing to the sandbox' do
      service = ArgyleService.new
      expected_url = "https://api-sandbox.argyle.com/v2"
      puts expected_url
      expect(service.instance_variable_get(:@http).url_prefix.to_s).to include(expected_url)
    end
  end

  describe '#items' do
    it 'returns a non-empty response' do
      service = ArgyleService.new
      # Stub the HTTP call to return a non-empty JSON response
      fake_response = instance_double(Faraday::Response, body: '[{"id": "12345"}]')
      allow_any_instance_of(Faraday::Connection).to receive(:get).with("items", { q: nil }).and_return(fake_response)

      response = service.items
      expect(response).not_to be_empty
      expect(response.first['id']).to eq("12345")
    end
  end

  describe '#payroll_documents' do
    context 'when ConnectedArgyleAccount exists' do
      before do
        # simulate that we have a ConnectedArgyleAccount record
        allow(ConnectedArgyleAccount).to receive(:exists?).with(user_id: user_id, account_id: account_id).and_return(true)
        # simulate that fetching the payroll documents returns a non-empty JSON response resembling payroll data
        allow_any_instance_of(Faraday::Connection).to receive(:get).with("payroll-documents", { account: account_id, user: user_id }).and_return(fake_response)
      end

      it 'returns payroll documents' do
        response = service.payroll_documents(account_id, user_id)
        expect(response).not_to be_empty
        expect(response['data'][0]['id']).to eq(JSON.parse(fake_response.body)['data'][0]['id'])
      end
    end

    context 'when ConnectedArgyleAccount does not exist' do
      before do
        allow(ConnectedArgyleAccount).to receive(:exists?).with(user_id: user_id, account_id: account_id).and_return(false)
      end

      it 'returns an error message' do
        response = service.payroll_documents(account_id, user_id)
        expect(response).to eq({ error: "No matching account found for the provided user_id and account_id." })
      end
    end
  end
end
