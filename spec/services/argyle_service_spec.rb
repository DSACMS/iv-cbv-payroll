require 'rails_helper'

RSpec.describe ArgyleService, type: :service do
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
end
