# frozen_string_literal: true

require "faraday"

class ArgyleService
  ENVIRONMENTS = {
    sandbox: {
      base_url: "https://api-sandbox.argyle.com/v2",
      api_key_id: ENV["ARGYLE_API_TOKEN_SANDBOX_ID"],
      api_key_secret: ENV["ARGYLE_API_TOKEN_SANDBOX_SECRET"],
      webhook_secret: ENV["ARGYLE_WEBHOOK_SECRET_SANDBOX"]
    }
  }

  ITEMS_ENDPOINT = "items"
  USERS_ENDPOINT = "users"
  WEBHOOKS_ENDPOINT = "webhooks"

  def initialize(environment, api_key_id = nil, api_key_secret = nil)
    @api_key_id = api_key_id || ENVIRONMENTS.fetch(environment.to_sym)[:api_key_id]
    @api_key_secret = api_key_secret || ENVIRONMENTS.fetch(environment.to_sym)[:api_key_secret]
    @webhook_secret = ENVIRONMENTS.fetch(environment.to_sym)[:webhook_secret]
    @environment = ENVIRONMENTS.fetch(environment.to_sym) { |env| raise KeyError.new("ArgyleService unknown environment: #{env}") }

    client_options = {
      request: {
        open_timeout: 5,
        timeout: 5,
        params_encoder: Faraday::FlatParamsEncoder
      },
      url: @environment[:base_url]
    }
    @http = Faraday.new(client_options) do |conn|
      conn.set_basic_auth @api_key_id, @api_key_secret
      conn.response :raise_error
      conn.response :json, content_type: "application/json"
      conn.response :logger,
        Rails.logger,
        headers: true,
        bodies: true,
        log_level: :debug
    end
  end

  # Fetch all Argyle items
  def items(query = nil)
    @http.get("#{ITEMS_ENDPOINT}", { q: query }).body
  end

  def create_user
    @http.post("#{USERS_ENDPOINT}").body
  end

  # Webhook management methods
  def get_webhook_subscriptions
    @http.get("#{WEBHOOKS_ENDPOINT}").body
  end

  def create_webhook_subscription(events, url, name)
    payload = {
      events: events,
      name: name,
      url: url,
      secret: @webhook_secret
    }

    @http.post("#{WEBHOOKS_ENDPOINT}", payload).body
  end

  def delete_webhook_subscription(id)
    @http.delete("#{WEBHOOKS_ENDPOINT}/#{id}").body
  end

  def generate_signature_digest(payload, secret)
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha512"), secret, payload)
  end

  def verify_signature(signature, payload, secret)
    expected = generate_signature_digest(payload, secret)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected)
  end

  def webhook_secret
    @webhook_secret
  end
end
