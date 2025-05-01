module ArgyleApiHelper
  def argyle_stub_request_employer_search_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::EMPLOYER_SEARCH_ENDPOINT}})
      .to_return(
        status: 200,
        body: argyle_load_relative_json_file(user_folder, 'request_employer_search.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def argyle_stub_request_paystubs_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::PAYSTUBS_ENDPOINT}})
      .to_return(
        status: 200,
        body: argyle_load_relative_json_file(user_folder, 'request_paystubs.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def argyle_stub_request_gigs_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::GIGS_ENDPOINT}})
      .to_return(
        status: 200,
        body: argyle_load_relative_json_file(user_folder, 'request_gigs.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def argyle_stub_request_accounts_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::ACCOUNTS_ENDPOINT}})
      .to_return(
        status: 200,
        body: argyle_load_relative_json_file(user_folder, 'request_accounts.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def argyle_stub_request_identities_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::IDENTITIES_ENDPOINT}})
      .to_return(
        status: 200,
        body: argyle_load_relative_json_file(user_folder, 'request_identity.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def argyle_stub_request_employments_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::EMPLOYMENTS_ENDPOINT}})
      .to_return(
        status: 200,
        body: argyle_load_relative_json_file(user_folder, 'request_employment.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def stub_get_webhook_subscriptions_response
    stub_request(:get, /#{Aggregators::Sdk::ArgyleService::WEBHOOKS_ENDPOINT}/)
      .to_return(
        status: 200,
        body:   @webhooks.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_create_user_response
    stub_request(:post, /#{Aggregators::Sdk::ArgyleService::USERS_ENDPOINT}/).to_return do |_|
      response = argyle_load_relative_json_file('', 'response_create_user.json')
      {
        status: 200,
        body:   response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
    end
  end

  def stub_create_user_token_response
    stub_request(:post, /#{Aggregators::Sdk::ArgyleService::USER_TOKENS_ENDPOINT}/).to_return do |_|
      response = argyle_load_relative_json_file('', 'response_create_user_token.json')
      {
        status: 200,
        body:   response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
    end
  end

  def stub_create_webhook_subscription_response
    stub_request(:post, /#{Aggregators::Sdk::ArgyleService::WEBHOOKS_ENDPOINT}/)
      .to_return do |_|
      response = argyle_load_relative_json_file('', 'response_create_webhook_subscription.json')
      {
        status: 200,
        body:   response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
    end
  end

  def stub_delete_webhook
    stub_request(:delete, /#{Aggregators::Sdk::ArgyleService::WEBHOOKS_ENDPOINT}\/(.*)/)
      .to_return do |request|
      webhook_id = request.uri.path.split('/').last
      @webhooks['results'].reject! { |webhook| webhook['id'] == webhook_id }
      {
        status: 204,
        body: ''
      }
    end
  end

  def argyle_load_relative_file(user_folder, filename)
    File.read(File.join(
      File.dirname(__FILE__),
      "fixtures/argyle/#{user_folder}/#{filename}"
    ))
  end

  def argyle_load_relative_json_file(user_folder, filename)
    JSON.parse(argyle_load_relative_file(user_folder, filename))
  end

  def argyle_user_property_for(user_folder, fixture_type, property = nil)
    data = argyle_load_relative_json_file(user_folder, "request_#{fixture_type}.json")

    return data unless property

    if data.key?('results')
      data['results'].map { |result| result[property] }
    else
      data[property]
    end
  end
end
