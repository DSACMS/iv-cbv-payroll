require 'rails_helper'

RSpec.describe ArgyleWebhooksManager, type: :service do
  let(:argyle_webhooks_manager) { described_class.new }
  let(:ngrok_url) { 'https://ngrok-url.com' }
  let(:subscription_name) { 'test' }
  let(:response_webhooks) { JSON.parse(File.read('spec/support/fixtures/argyle/response_webooks.json')) }
  
  before do
    allow(ArgyleService).to receive(:fetch_webhook_subscriptions).and_return(response_webhooks)
  end

  describe 'create_subscription_if_necessary' do
    it 'creates a subscription if one does not exist' do
      argyle_webhooks_manager.create_subscription_if_necessary(ngrok_url, subscription_name)
      expect(argyle_webhooks_manager.create_subscription_if_necessary).to eq(true)
    
    end
  end
end