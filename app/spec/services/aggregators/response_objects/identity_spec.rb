require 'rails_helper'

RSpec.describe Aggregators::ResponseObjects::Identity do
  let(:pinwheel_response) do
    {
      "account_id" => "12345",
      "full_name" => "John Doe"
    }
  end

  let(:argyle_response) do
    {
      "account" => "67890",
      "full_name" => "Jane Smith"
    }
  end

  describe '.from_pinwheel' do
    it 'creates an Identity object from pinwheel response' do
      identity = described_class.from_pinwheel(pinwheel_response)
      expect(identity.account_id).to eq("12345")
      expect(identity.full_name).to eq("John Doe")
    end
  end

  describe '.from_argyle' do
    it 'creates an Identity object from argyle response' do
      identity = described_class.from_argyle(argyle_response)
      expect(identity.account_id).to eq("67890")
      expect(identity.full_name).to eq("Jane Smith")
    end
  end
end
