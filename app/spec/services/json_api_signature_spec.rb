require 'rails_helper'

RSpec.describe JsonApiSignature do
  let(:body) { '{"test":"data"}' }
  let(:timestamp) { "1640995200" }
  let(:api_key) { "test-api-key" }

  describe '.generate' do
    it 'generates a valid HMAC sha512 signature' do
      signature = described_class.generate(body, timestamp, api_key)

      # sha512 hex is always 128 characters...
      expect(signature.length).to eq(128)
    end

    it 'generates the same signature from the same inputs' do
      signature1 = described_class.generate(body, timestamp, api_key)
      signature2 = described_class.generate(body, timestamp, api_key)

      expect(signature1).to eq(signature2)
    end

    it 'generates different signatures for different inputs' do
      signature1 = described_class.generate(body, timestamp, api_key)
      signature2 = described_class.generate(body, "different_timestamp", api_key)

      expect(signature1).not_to eq(signature2)
    end
  end

  describe '.verify' do
    it 'returns true for valid signatures' do
      signature = described_class.generate(body, timestamp, api_key)

      expect(described_class.verify(body, timestamp, signature, api_key)).to be true
    end

    it 'returns false for invalid signatures' do
      expect(described_class.verify(body, timestamp, "invalid-signature", api_key)).to be false
    end

    it 'returns false when body is different' do
      signature = described_class.generate(body, timestamp, api_key)

      expect(described_class.verify("different body", timestamp, signature, api_key)).to be false
    end
  end
end
