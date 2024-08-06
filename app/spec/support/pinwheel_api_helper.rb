module PinwheelApiHelper
  def stub_environment_variable(variable, value, &block)
    previous_value = ENV[variable]
    ENV[variable] = value
    block.call
    ENV[variable] = previous_value
  end

  def stub_request_items_response
    stub_request(:get, /#{PinwheelService::ITEMS_ENDPOINT}/)
      .to_return(
        status: 200,
        body: {
          results: [ {
                      id: "12345"
                    } ]
        }.to_json,
        headers: { content_type: 'application/json;charset=UTF-8' }
      )
  end

  def stub_create_token_response(end_user_id: 'user_id')
    stub_request(:post, /#{PinwheelService::USER_TOKENS_ENDPOINT}/)
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

  def stub_refresh_user_token_response
    stub_request(:post, /#{PinwheelService::USER_TOKENS_ENDPOINT}/)
      .to_return(
        status: 200,
        body: { "user_token": "abc123" }.to_json,
        headers: { content_type: 'application/json;charset=UTF-8' }
      )
  end

  def stub_request_end_user_paystubs_response
    stub_request(:get, %r{#{PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/paystubs})
      .to_return(
        status: 200,
        body: load_relative_json_file('request_end_user_paystubs_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def stub_request_employment_info_response
    stub_request(:get, %r{#{PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/employment})
      .to_return(
        status: 200,
        body: load_relative_json_file('request_employment_info_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def stub_request_income_metadata_response
    stub_request(:get, %r{#{PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/income})
      .to_return(
        status: 200,
        body: load_relative_json_file('request_income_metadata_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def stub_request_end_user_accounts_response
    stub_request(:get, %r{#{PinwheelService::END_USERS}/[0-9a-fA-F\-]{36}/accounts})
      .to_return(
        status: 200,
        body: load_relative_json_file('request_end_user_accounts_response.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def request_employment_info_response_null_employment_status_bug
    stub_request(:get, %r{#{PinwheelService::ACCOUNTS_ENDPOINT}/[0-9a-fA-F\-]{36}/employment})
      .to_return(
        status: 200,
        body: load_relative_json_file('request_employment_info_response_null_employment_status_bug.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
  end

  def load_relative_file(filename)
    File.read(File.join(
      File.dirname(__FILE__),
      "fixtures/pinwheel/#{filename}"
    ))
  end

  def load_relative_json_file(filename)
    JSON.parse(load_relative_file(filename))
  end
end
