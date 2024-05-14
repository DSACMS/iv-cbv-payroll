# frozen_string_literal: true

require "faraday"

class ArgyleService
  USERS_ENDPOINT = 'https://api-sandbox.argyle.com/v2/users';
  USER_TOKENS_ENDPOINT = 'https://api-sandbox.argyle.com/v2/user-tokens';
  ITEMS_ENDPOINT = 'https://api-sandbox.argyle.com/v2/items';
  PAYSTUBS_ENDPOINT = 'https://api-sandbox.argyle.com/v2/paystubs?user='

  def initialize
    api_key = Rails.application.credentials.argyle[:api_key]
    base_url = ENV["ARGYLE_API_URL"] || "https://api-sandbox.argyle.com/v2"

    raise "ARGYLE_API_TOKEN environment variable is blank. Make sure you have the .env.local.local from 1Password." if api_key.blank?

    client_options = {
      request: {
        open_timeout: 5,
        timeout: 5
      },
      url: base_url,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Basic #{api_key}"
      }
    }
    @http = Faraday.new(client_options)
  end

  def fetch_paystubs(options)
    response = @http.get("paystubs", options)
    JSON.parse(response.body)
  end

  def fetch_items(options)
    response = @http.get("items", options)
    JSON.parse(response.body)
  end

  def create_user
    response = @http.post(USERS_ENDPOINT)
    JSON.parse(response.body)
  end

  def refresh_user_token(user_id)
    response = @http.post(USER_TOKENS_ENDPOINT, { user: user_id }.to_json)
    JSON.parse(response.body)
  end
end
