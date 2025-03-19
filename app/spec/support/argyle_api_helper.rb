module ArgyleApiHelper
  def stub_get_webhook_subscriptions_response
    stub_request(:get, /#{ArgyleService::WEBHOOKS_ENDPOINT}/)
      .to_return(
        status: 200,
        body:   @webhooks.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_create_webhook_subscription_response
    stub_request(:post, /#{ArgyleService::WEBHOOKS_ENDPOINT}/)
      .to_return do |_|
        response = load_relative_json_file('argyle', 'response_create_webhook_subscription.json')
        {
          status: 200,
          body:   response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        }
      end
  end

  def stub_delete_webhook
    stub_request(:delete, /#{ArgyleService::WEBHOOKS_ENDPOINT}\/(.*)/)
      .to_return do |request|
        webhook_id = request.uri.path.split('/').last
        @webhooks['results'].reject! { |webhook| webhook['id'] == webhook_id }
        {
          status: 204,
          body: ''
        }
      end
  end

  # this is separated so that we can use the same stubbed data for multiple tests
  def stub_webhook_subscriptions
    @webhooks = read_webhooks_fixture
  end

  def read_webhooks_fixture
    load_relative_json_file('argyle', 'response_get_webhook_subscriptions.json')
  end
end
