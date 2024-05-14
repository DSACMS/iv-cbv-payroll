# frozen_string_literal: true

require "faraday"

class ArgyleService
  BASE_URL = "https://api-sandbox.argyle.com/v2"
  USERS_ENDPOINT = 'users';
  USER_TOKENS_ENDPOINT = 'user-tokens';
  ITEMS_ENDPOINT = 'items';
  PAYSTUBS_ENDPOINT = 'paystubs'

  def initialize
    api_key = Rails.application.credentials.argyle[:api_key]

    raise "ARGYLE_API_TOKEN environment variable is blank. Make sure you have the .env.local.local from 1Password." if api_key.blank?

    client_options = {
      request: {
        open_timeout: 5,
        timeout: 5
      },
      url: BASE_URL,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Basic #{api_key}"
      }
    }
    @http = Faraday.new(client_options)
  end

  def build_url(endpoint)
    @http.build_url(endpoint).to_s
  end

  def fetch_paystubs(options)
    response = @http.get(build_url(PAYSTUBS_ENDPOINT), options)
    JSON.parse(response.body)
  end

  def fetch_items(options)
    response = @http.get(build_url(ITEMS_ENDPOINT), options)
    JSON.parse(response.body)
  end

  def create_user
    response = @http.post(build_url(USERS_ENDPOINT))
    JSON.parse(response.body)
  end

  def refresh_user_token(user_id)
    response = @http.post(build_url(USER_TOKENS_ENDPOINT), { user: user_id }.to_json)
    JSON.parse(response.body)
  end
end
