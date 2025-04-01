module ArgyleApiHelper
  def stub_request_items_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::ITEMS_ENDPOINT}})
      .to_return(
        status: 200,
        body: load_relative_json_file(user_folder, 'request_items.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def stub_request_paystubs_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::PAYSTUBS_ENDPOINT}})
      .to_return(
        status: 200,
        body: load_relative_json_file(user_folder, 'request_paystubs.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def stub_request_accounts_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::ACCOUNTS_ENDPOINT}})
      .to_return(
        status: 200,
        body: load_relative_json_file(user_folder, 'request_accounts.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def stub_request_identities_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::IDENTITIES_ENDPOINT}})
      .to_return(
        status: 200,
        body: load_relative_json_file(user_folder, 'request_identity.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def stub_request_employments_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::EMPLOYMENTS_ENDPOINT}})
      .to_return(
        status: 200,
        body: load_relative_json_file(user_folder, 'request_employment.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

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
