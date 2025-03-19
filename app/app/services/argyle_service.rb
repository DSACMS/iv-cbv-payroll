# frozen_string_literal: true

require "faraday"

class ArgyleService
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error
    attr_reader :status, :response_body

    def initialize(status, response_body)
      @status = status
      @response_body = response_body
      super("Argyle API error: #{status} - #{response_body}")
    end
  end

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
    @environment = ENVIRONMENTS.fetch(environment.to_sym) { |env| raise ConfigurationError.new("ArgyleService unknown environment: #{env}") }
    
    client_options = {
      request: {
        open_timeout: 5,
        timeout: 5,
        params_encoder: Faraday::FlatParamsEncoder
      },
      url: @environment[:base_url],
      headers: {
        "Content-Type" => "application/json",
      }
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
    make_request(:get, ITEMS_ENDPOINT, { q: query })
  end

  def create_user
    make_request(:post, USERS_ENDPOINT)
  end

  # Webhook management methods
  def get_webhook_subscriptions
    make_request(:get, WEBHOOKS_ENDPOINT)
  end

  def create_webhook_subscription(events, url, name)
    payload = {
      events: events,
      name: name,
      url: url,
      secret: @webhook_secret
    }

    make_request(:post, WEBHOOKS_ENDPOINT, payload)
  end

  def delete_webhook_subscription(id)
    make_request(:delete, "#{WEBHOOKS_ENDPOINT}/#{id}")
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

  private

  def make_request(method, endpoint, params = nil)
    response = case method
    when :get
      @http.get(endpoint, params)
    when :post
      @http.post(endpoint, params&.to_json)
    when :delete
      @http.delete(endpoint)
    end

    response.body
  rescue Faraday::Error => e
    status = e.response&.dig(:status)
    body = e.response&.dig(:body)
    Rails.logger.error "Argyle API error: #{status} - #{body}"
    raise ApiError.new(status, body)
  rescue StandardError => e
    Rails.logger.error "Unexpected error in Argyle API request: #{e.message}"
    raise ApiError.new(:unknown, e.message)
  end
end
