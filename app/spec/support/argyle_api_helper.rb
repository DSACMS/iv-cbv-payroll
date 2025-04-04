module ArgyleApiHelper
  def argyle_stub_request_items_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::ITEMS_ENDPOINT}})
      .to_return(
        status: 200,
        body: argyle_load_relative_json_file(user_folder, 'request_items.json').to_json,
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

  def argyle_stub_request_accounts_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::ACCOUNTS_ENDPOINT}})
      .to_return(
        status: 200,
        body: argyle_load_relative_json_file(user_folder, 'request_accounts.json').to_json,
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

  def argyle_stub_request_employments_response(user_folder)
    stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::EMPLOYMENTS_ENDPOINT}})
      .to_return(
        status: 200,
        body: argyle_load_relative_json_file(user_folder, 'request_employment.json').to_json,
        headers: { 'Content-Type': 'application/json;charset=UTF-8' }
      )
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
end
