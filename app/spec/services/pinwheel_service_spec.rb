require 'rails_helper'

RSpec.describe PinwheelService, type: :service do
  include PinwheelApiHelper
  let(:service) { PinwheelService.new("sandbox", "FAKE_API_KEY") }
  let(:end_user_id) { 'abc123' }

  describe '#fetch_items' do
    before do
      stub_request_items_response
    end

    it 'returns a non-empty response' do
      response = service.fetch_items({ q: 'test' })
      expect(response).not_to be_empty
    end
  end

  describe '#create_link_token' do
    before do
      stub_create_token_response(end_user_id: end_user_id)
    end

    it 'returns a user token' do
      response = service.create_link_token(end_user_id: end_user_id, response_type: 'employer', id: 'fake_id', language: 'en')
      expect(response['data']['id']).to eq(end_user_id)
    end

    context "with an empty response_type and id" do
      it 'returns a user token' do
        response = service.create_link_token(end_user_id: end_user_id, response_type: '', id: '', language: 'en')
        expect(response['data']['id']).to eq(end_user_id)
      end
    end
  end

  describe "#verify_webhook_signature" do
    # https://docs.pinwheelapi.com/public/docs/webhook-signature-verification
    let(:service) { PinwheelService.new("sandbox", "TEST_KEY") }
    let(:raw_request_body) {
      load_relative_file('test_data_1_base.json')
    }

    let(:timestamp) {
      '860860860'
    }

    let(:signature_digest) {
      'v2=42fb9eba200e821d4de63667f5a30f7e1b83609b135e148e26ce01eef2aa6ba8'
    }

    it 'generates the correct signature' do
      expect(service.generate_signature_digest(timestamp, raw_request_body)).to eq(signature_digest)
    end

    it 'compares a valid signature' do
      digest = service.generate_signature_digest(timestamp, raw_request_body)
      expect(service.verify_signature(signature_digest, digest)).to eq(true)
    end
  end

  describe 'Error handling' do
    skip 'raises an error when receiving a 400' do
    end
  end
end
