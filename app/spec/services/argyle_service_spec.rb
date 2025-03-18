require 'rails_helper'

RSpec.describe ArgyleService, type: :service do
  include ArgyleApiHelper
  let(:argyle_service) do
    described_class.new('sandbox', ENV['ARGYLE_API_TOKEN_SANDBOX_ID'], ENV['ARGYLE_API_TOKEN_SANDBOX_SECRET'])
  end

  describe '#items' do
    before do
      stub_webhook_subscriptions_response
    end

    it 'returns a list of webhook subscriptions' do
      expect(argyle_service.fetch_webhook_subscriptions).to_not eq([])
    end
  end
end
