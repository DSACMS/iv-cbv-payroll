# frozen_string_literal: true

require "faraday"
require "fileutils"
require "json"

class ArgyleService
  attr_reader :webhook_secret

  ENVIRONMENTS = {
    sandbox: {
      base_url: "https://api-sandbox.argyle.com/v2",
      api_key_id: ENV["ARGYLE_SANDBOX_API_TOKEN_ID"],
      api_key_secret: ENV["ARGYLE_SANDBOX_API_TOKEN_SECRET"],
      webhook_secret: ENV["ARGYLE_SANDBOX_WEBHOOK_SECRET"]
    },
    production: {
      base_url: "https://api.argyle.com/v2",
      api_key_id: ENV["ARGYLE_API_TOKEN_ID"],
      api_key_secret: ENV["ARGYLE_API_TOKEN_SECRET"],
      webhook_secret: ENV["ARGYLE_WEBHOOK_SECRET"]
    }
  }

  ITEMS_ENDPOINT = "items"
  PAYSTUBS_ENDPOINT = "paystubs"
  IDENTITIES_ENDPOINT = "identities"
  USERS_ENDPOINT = "users"
  ACCOUNTS_ENDPOINT = "accounts"
  EMPLOYMENTS_ENDPOINT = "employments"
  WEBHOOKS_ENDPOINT = "webhooks"

  def initialize(environment, api_key_id = nil, api_key_secret = nil, webhook_secret = nil)
    @api_key_id = api_key_id || ENVIRONMENTS.fetch(environment.to_sym)[:api_key_id]
    @api_key_secret = api_key_secret || ENVIRONMENTS.fetch(environment.to_sym)[:api_key_secret]
    @webhook_secret = webhook_secret || ENVIRONMENTS.fetch(environment.to_sym)[:webhook_secret]
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

  def get_webhook_subscriptions
    make_request(:get, WEBHOOKS_ENDPOINT)
  end

  def create_webhook_subscription(events, url, name)
    payload = {
      events: events,
      name: name,
      url: url,
      secret: @webhook_secret

      # Not all events support the "include_resource" parameter so we'll omit it
      #
      # @response
      # Argyle API error: 400 -
      # {"config"=>["only allowed for accounts.added, accounts.connected, accounts.failed,
      # accounts.updated, gigs.partially_synced, items.removed, items.updated, paystubs.partially_synced,
      # shifts.partially_synced"]
      #
      # config: {
      #   include_resource: true
      # }
    }

    make_request(:post, WEBHOOKS_ENDPOINT, payload)
  end

  def delete_webhook_subscription(id)
    make_request(:delete, "#{WEBHOOKS_ENDPOINT}/#{id}")
  end

  def fetch_paystubs(**params)
    json = fetch_paystubs_api(**params)
    json["results"].map { |paystub_json| ResponseObjects::Paystub.from_argyle(paystub_json) }
  end

  def fetch_employments(**params)
    # Note: we actually fetch Argyle's identity API instead of employment for the correct data
    json = fetch_identities_api(**params)
    json["results"].map { |identity_json| ResponseObjects::Employment.from_argyle(identity_json) }
  end

  def fetch_incomes(**params)
    # Note: we actually fetch Argyle's identity API instead of employment for the correct data
    json = fetch_identities_api(**params)
    json["results"].map { |identity_json| ResponseObjects::Income.from_argyle(identity_json) }
  end

  # https://docs.argyle.com/api-reference/identities#retrieve
  def fetch_identities(**params)
    # todo: paginate
    json = fetch_identities_api(**params)
    json["results"].map { |identity_json| ResponseObjects::Identity.from_argyle(identity_json) }
  end

  # Fetch all Argyle items
  # https://docs.argyle.com/api-reference/items#list
  def items(query = nil)
    make_request(:get, ITEMS_ENDPOINT, { q: query })
  end

  # https://docs.argyle.com/api-reference/users#retrieve
  def fetch_user_api(user:)
    make_request(:get, "#{USERS_ENDPOINT}/#{user}")
  end

  # https://docs.argyle.com/api-reference/identities#list
  def fetch_identities_api(**params)
    # todo: paginate
    make_request(:get, IDENTITIES_ENDPOINT, params)
  end

  # https://docs.argyle.com/api-reference/accounts#list
  def fetch_accounts_api(**params)
    # TODO: paginate
    make_request(:get, ACCOUNTS_ENDPOINT, params)
  end

  # https://docs.argyle.com/api-reference/paystubs#list
  def fetch_paystubs_api(**params)
    # TODO: paginate
    make_request(:get, PAYSTUBS_ENDPOINT, params)
  end

  def create_user(cbv_flow_end_user_id = nil)
    params = cbv_flow_end_user_id.present? ? { external_id: cbv_flow_end_user_id } : {}
    make_request(:post, USERS_ENDPOINT, params)
  end

  # https://docs.argyle.com/api-reference/employments#list
  def fetch_employments_api(**params)
    make_request(:get, EMPLOYMENTS_ENDPOINT, params)
  end

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
  rescue StandardError => e
    Rails.logger.error "Unexpected error in Argyle API request: #{e.message}"
  end

  # TODO: refactor this into common function between argyle_service/pinwheel_service
  def build_url(endpoint)
    @http.build_url(endpoint).to_s
  end
end
