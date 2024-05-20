# frozen_string_literal: true

require "faraday"

class ArgyleService
  BASE_URL = "https://api-sandbox.argyle.com"
  USERS_ENDPOINT = "/v2/users"
  USER_TOKENS_ENDPOINT = "/v2/user-tokens"
  ITEMS_ENDPOINT = "/v2/items"
  PAYSTUBS_ENDPOINT = "/v2/paystubs"
  WEBHOOKS_ENDPOINT = "/v2/webhooks"

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
    @http = Faraday.new(client_options) do |conn|
      # Parse JSON responses
      conn.response :json
    end
  end

  def build_url(endpoint)
    @http.build_url(endpoint).to_s
  end

  def fetch_paystubs(options)
    @http.get(build_url(PAYSTUBS_ENDPOINT), options).body
  end

  def fetch_items(options)
    @http.get(build_url(ITEMS_ENDPOINT), options).body
  end

  def create_user
    @http.post(build_url(USERS_ENDPOINT)).body
  end

  def refresh_user_token(user_id)
    @http.post(build_url(USER_TOKENS_ENDPOINT), { user: user_id }.to_json).body
  end

  def fetch_webhook_subscriptions
    @http.get(build_url(WEBHOOKS_ENDPOINT)).body
  end

  def delete_webhook_subscription(id)
    webhook_url = URI.join(build_url(WEBHOOKS_ENDPOINT) + "/", id)
    @http.delete(webhook_url).body
  end

  def create_webhook_subscription(events, name, url, secret)
    @http.post(build_url(WEBHOOKS_ENDPOINT), {
      name: name,
      events: events,
      url: url,
      secret: secret,
    }.to_json).body
  end
end
