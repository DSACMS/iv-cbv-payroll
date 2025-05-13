module PinwheelApiHelper
  def stub_environment_variable(variable, value, &block)
    previous_value = ENV[variable]
    ENV[variable] = value
    block.call
    ENV[variable] = previous_value
  end

  def pinwheel_stub_request_items_response
    stub_request(:get, /#{Aggregators::Sdk::PinwheelService::ITEMS_ENDPOINT}/)
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_items_response.json').to_json,
        headers: { content_type: 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_request_items_no_items_response
    stub_request(:get, /#{Aggregators::Sdk::PinwheelService::ITEMS_ENDPOINT}/)
      .to_return(
        status: 200,
        body: {
          data: []
        }.to_json,
        headers: { content_type: 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_create_token_response(end_user_id: 'user_id')
    stub_request(:post, /#{Aggregators::Sdk::PinwheelService::USER_TOKENS_ENDPOINT}/)
      .to_return(
        status: 200,
        body: {
          data: {
            token: 'abc123',
            id: end_user_id
          }
        }.to_json,
        headers: { content_type: 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_refresh_user_token_response
    stub_request(:post, /#{Aggregators::Sdk::PinwheelService::USER_TOKENS_ENDPOINT}/)
      .to_return(
        status: 200,
        body: { "user_token": "abc123" }.to_json,
        headers: { content_type: 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_request_end_user_paystubs_response
    stub_request(:get, %r{#{Aggregators::Sdk::PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/paystubs})
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_end_user_paystubs_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_request_end_user_multiple_paystubs_response
    stub_request(:get, %r{#{Aggregators::Sdk::PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/paystubs})
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_end_user_multiple_paystubs_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_request_end_user_no_paystubs_response
    stub_request(:get, %r{#{Aggregators::Sdk::PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/paystubs})
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_end_user_no_paystubs_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_request_end_user_no_hours_response
    stub_request(:get, %r{#{Aggregators::Sdk::PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/paystubs})
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_end_user_paystubs_with_no_hours_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_request_employment_info_response
    stub_request(:get, %r{#{Aggregators::Sdk::PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/employment})
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_employment_info_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_request_employment_info_response_null_employment_status_bug
    stub_request(:get, %r{#{Aggregators::Sdk::PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/employment})
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_employment_info_response_null_employment_status_bug.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_request_employment_info_gig_worker_response
    stub_request(:get, %r{#{Aggregators::Sdk::PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/employment})
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_employment_info_gig_worker_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_request_income_metadata_response
    stub_request(:get, %r{#{Aggregators::Sdk::PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/income})
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_income_metadata_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_request_end_user_accounts_response
    stub_request(:get, %r{#{Aggregators::Sdk::PinwheelService::END_USERS}/[0-9a-fA-F\-]{36}/accounts})
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_end_user_accounts_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_request_end_user_account_response
    stub_request(:get, %r{#{Aggregators::Sdk::PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}})
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_end_user_accounts_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_request_identity_response
    stub_request(:get, %r{#{Aggregators::Sdk::PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/identity})
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_identity_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_request_platform_response
    stub_request(:get, %r{#{Aggregators::Sdk::PinwheelService::PLATFORMS_ENDPOINT}/[0-9a-fA-F\-]{36}})
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_platform_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_stub_request_shifts_response
    stub_request(:get, %r{#{Aggregators::Sdk::PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/shifts})
      .to_return(
        status: 200,
        body: pinwheel_load_relative_json_file('request_end_user_shifts_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def pinwheel_load_relative_file(filename)
    File.read(File.join(
      File.dirname(__FILE__),
      "fixtures/pinwheel/#{filename}"
    ))
  end

  def pinwheel_load_relative_json_file(filename)
    JSON.parse(pinwheel_load_relative_file(filename))
  end
end
