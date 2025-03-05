require 'rails_helper'

RSpec.describe ArgyleService, type: :service do
  include ArgyleApiHelper
  let(:service) { ArgyleService.new("sandbox", "FAKE_API_KEY") }
  let(:end_user_id) { 'abc123' }

  describe '#fetch_items' do
    before do
      stub_request_items_response
    end

    it 'returns a non-empty response' do
      response = service.items('test')
      expect(response).not_to be_empty
    end
  end

  describe '#fetch_paystubs' do
    before do
      stub_request_paystubs_response
    end

    it 'returns a non-empty response' do
      response = service.fetch_paystubs(account_id: end_user_id)
      expect(response).not_to be_empty
    end
  end
end
