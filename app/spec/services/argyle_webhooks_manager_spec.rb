require 'rails_helper'

RSpec.describe ArgyleWebhooksManager, type: :service do
  let(:argyle_webhooks_manager) { described_class.new }
  let(:ngrok_url) { 'https://ngrok-url.com' }
  let(:subscription_name) { 'test' }

  before do
  end

  describe 'create_subscription_if_necessary' do
    it 'creates a subscription if one does not exist' do
    end
  end
end
