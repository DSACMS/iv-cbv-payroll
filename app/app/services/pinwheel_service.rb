# frozen_string_literal: true

require "faraday"

class PinwheelService
  BASE_URL = "https://sandbox.getpinwheel.com"
  USERS_ENDPOINT = "/v1/accounts"
  USER_TOKENS_ENDPOINT = "/v1/link_tokens"
  ITEMS_ENDPOINT = "/v1/search"
  PAYSTUBS_ENDPOINT = "/paystubs"
  WEBHOOKS_ENDPOINT = "/v1/webhooks"

  def initialize
    api_key = ENV["PINWHEEL_API_TOKEN"]

    raise "PINWHEEL_API_TOKEN environment variable is blank. Make sure you have the .env.local.local from 1Password." if api_key.blank?

    client_options = {
      request: {
        open_timeout: 5,
        timeout: 5
      },
      url: BASE_URL,
      headers: {
        "Content-Type" => "application/json",
        "Pinwheel-Version" => "2023-11-22",
        "X-API-SECRET" => "#{api_key}"
      }
    }
    @http = Faraday.new(client_options) do |conn|
      conn.response :raise_error
      conn.response :json, content_type: "application/json"
    end
  end

  def build_url(endpoint)
    @http.build_url(endpoint).to_s
  end

  def fetch_items(options)
    @http.get(build_url(ITEMS_ENDPOINT), options).body
  end

  def create_link_token(end_user_id:, response_type:, id:)
    @http.post(build_url(USER_TOKENS_ENDPOINT), {
      org_name: "Verify.gov",
      required_jobs: [ "paystubs", "employment", "income" ],
      end_user_id: end_user_id,
      skip_intro_screen: true,
      "#{response_type}_id": id
    }.to_json).body
  end
end
