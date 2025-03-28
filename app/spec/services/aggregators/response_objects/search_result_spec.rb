require 'rails_helper'

RSpec.describe Aggregators::ResponseObjects::SearchResult, type: :model do
  describe '.from_pinwheel' do
    let(:response_body) do
      {
        "response_type" => "success",
        "id" => "123",
        "name" => "ACME Corporation",
        "logo_url" => "http://example.com/logo.png"
      }
    end

    it 'creates an SearchResult object from pinwheel response' do
      search_result = described_class.from_pinwheel(response_body)
      expect(search_result.provider_name).to eq(:pinwheel)
      expect(search_result.provider_options).to eq({ response_type: "success", provider_id: "123" })
      expect(search_result.name).to eq("ACME Corporation")
      expect(search_result.logo_url).to eq("http://example.com/logo.png")
    end
  end

  describe '.from_argyle' do
    let(:response_body) do
      {
        "kind" => "success",
        "id" => "456",
        "name" => "ACME Corporation",
        "logo_url" => "http://example.com/logo.png"
      }
    end

    it 'creates an SearchResult object from argyle response' do
      search_result = described_class.from_argyle(response_body)
      expect(search_result.provider_name).to eq(:argyle)
      expect(search_result.provider_options).to eq({ response_type: "success", provider_id: "456" })
      expect(search_result.name).to eq("ACME Corporation")
      expect(search_result.logo_url).to eq("http://example.com/logo.png")
    end
  end
end
