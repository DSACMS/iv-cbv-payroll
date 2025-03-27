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
      api_key_id: ENV["ARGYLE_SANDBOX_API_TOKEN_ID"],
      api_key_secret: ENV["ARGYLE_SANDBOX_API_TOKEN_SECRET"],
      webhook_secret: ENV["ARGYLE_SANDBOX_WEBHOOK_SECRET"]
    }
  }

  ITEMS_ENDPOINT = "items"
  USERS_ENDPOINT = "users"
  WEBHOOKS_ENDPOINT = "webhooks"

  # Argyle's event outcomes are implied by the event name themselves i.e. accounts.failed (implies error)
  # x.fully_synced (implies success)

  # Define all webhook events we're interested in with their outcomes
  # and corresponding synchronizations page "job"
  SUBSCRIBED_WEBHOOK_EVENTS = {
    "users.fully_synced" => {
      status: :success,
      job: %w[income]
    },
    "identities.added" => {
      status: :success,
      job: %w[identity]
    },
    "paystubs.fully_synced" => {
      status: :success,
      job: %w[paystubs employment]
    },
    "gigs.fully_synced" => {
      status: :success,
      job: %w[gigs] # TODO: [FFS-XXX] update front-end/client to support gigs sync status
    },
    "accounts.connected" => {
      status: :success,
      job: [] # we're not concerned with reporting this to the front-end/client
    },
    # Failed to sync
    "accounts.failed" => {
      status: :failed,
      job: %w[paystubs]
    }
  }.freeze

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
        "Content-Type" => "application/json"
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

  def create_user(cbv_flow_end_user_id = nil)
    payload = cbv_flow_end_user_id.present? ? { external_id: cbv_flow_end_user_id } : {}
    make_request(:post, USERS_ENDPOINT, payload)
  end

  # Webhook management methods
  def get_webhook_subscriptions
    make_request(:get, WEBHOOKS_ENDPOINT)
  end

  def get_environment
    @environment
  end

  def create_webhook_subscription(events, url, name)
    payload = {
      events: events,
      name: name,
      url: url,
      secret: @webhook_secret,
      # Not all events support the include_resource so we'll omit it
      #
      # @response
      # Argyle API error: 400 -
      # {"config"=>["only allowed for accounts.added, accounts.connected, accounts.failed, 
      # accounts.updated, gigs.partially_synced, items.removed, items.updated, paystubs.partially_synced, 
      # shifts.partially_synced"]}

      # config: {
      #   include_resource: true
      # }
    }

    make_request(:post, WEBHOOKS_ENDPOINT, payload)
  end

  def delete_webhook_subscription(id)
    make_request(:delete, "#{WEBHOOKS_ENDPOINT}/#{id}")
  end

  def generate_signature_digest(payload)
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha512"), @webhook_secret, payload)
  end

  def self.verify_signature(signature, payload)
    expected = generate_signature_digest(payload)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected)
  end

  def self.get_webhook_events
    SUBSCRIBED_WEBHOOK_EVENTS.keys
  end

  def self.get_supported_jobs
    SUBSCRIBED_WEBHOOK_EVENTS.values.map { |event| event[:job] }.flatten.compact.uniq
  end

  def self.get_webhook_event_outcome(event)
    SUBSCRIBED_WEBHOOK_EVENTS[event][:status]
  end

  def self.get_webhook_event_jobs(event)
    SUBSCRIBED_WEBHOOK_EVENTS[event][:job]
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
