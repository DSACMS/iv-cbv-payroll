module ArgyleApiHelper
  def stub_environment_variable(variable, value, &block)
    previous_value = ENV[variable]
    ENV[variable] = value
    block.call
    ENV[variable] = previous_value
  end

  def stub_webhook_subscriptions_response
    stub_request(:get, /#{ArgyleService::WEBHOOKS_ENDPOINT}/)
      .to_return(
        status: 200,
        body: load_relative_json_file('argyle', 'response_webhooks.json').to_json,
      )
  end
end