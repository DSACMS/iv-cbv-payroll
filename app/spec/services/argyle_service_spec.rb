require 'rails_helper'

RSpec.describe ArgyleService, type: :service do
  include ArgyleApiHelper

  let(:argyle_service) do
    described_class.new('sandbox', ENV['ARGYLE_API_TOKEN_SANDBOX_ID'], ENV['ARGYLE_API_TOKEN_SANDBOX_SECRET'])
  end

  let(:web_hook_response) do
    load_relative_json_file('argyle', 'response_get_webhook_subscriptions.json')
  end

  describe '#fetch_webhook_subscriptions' do
    before do
      stub_webhook_subscriptions
      stub_get_webhook_subscriptions_response
    end

    it 'returns a list of webhook subscriptions' do
      expect(argyle_service.get_webhook_subscriptions).to eq(web_hook_response)
    end
  end
end
