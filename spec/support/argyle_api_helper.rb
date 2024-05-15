module ArgyleApiHelper
  def stub_request_items_response
    stub_request(:get, /#{ArgyleService::ITEMS_ENDPOINT}/)
      .to_return(status: 200, body: {
        results: [{
          id: "12345"
        }]
      }.to_json)
  end

  def stub_request_paystubs_response
    stub_request(:get, /#{ArgyleService::PAYSTUBS_ENDPOINT}/)
      .to_return(status: 200, body: load_relative_json_file('request_paystubs_response.json').to_json)
  end

  def stub_create_user_response(user_id: 'user_id')
    stub_request(:post, /#{ArgyleService::USERS_ENDPOINT}/)
      .to_return(status: 200, body: {
        user_token: 'abc123',
        id: user_id}.to_json
      )
  end

  def stub_refresh_user_token_response
    stub_request(:post, /#{ArgyleService::USER_TOKENS_ENDPOINT}/)
      .to_return(status: 200, body: {"user_token": "abc123"}.to_json)
  end

  def load_relative_json_file(filename)
    path = File.join(
      File.dirname(__FILE__),
      "fixtures/argyle/#{filename}"
    )
    JSON.parse(File.read(path))
  end
end
