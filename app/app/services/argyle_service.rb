# frozen_string_literal: true

require "faraday"

class ArgyleService
  ENVIRONMENTS = {
    sandbox: {
      base_url: "https://api-sandbox.argyle.com/v2",
      api_key_id: ENV["ARGYLE_API_TOKEN_SANDBOX_ID"],
      api_key_secret: ENV["ARGYLE_API_TOKEN_SANDBOX_SECRET"]
    }
  }

  ITEMS_ENDPOINT = "items"
  PAYSTUBS_ENDPOINT = "paystubs"
  IDENTITIES_ENDPOINT = "identities"

  def initialize(environment, api_key_id = nil, api_key_secret = nil)
    @api_key_id = api_key_id || ENVIRONMENTS.fetch(environment.to_sym)[:api_key_id]
    @api_key_secret = api_key_secret || ENVIRONMENTS.fetch(environment.to_sym)[:api_key_secret]
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
    @http.get(ITEMS_ENDPOINT, { q: query }).body
  end

  def fetch_user(end_user_id:)
    @http.get(build_url("users/#{end_user_id}")).body
  end

  # https://docs.argyle.com/api-reference/identities#retrieve
  def fetch_identity(end_user_id:)
    @http.get(build_url("identities/#{end_user_id}")).body
  end

  def fetch_paystubs(account_id:)
    # json["data"].map { |paystub_json| ResponseObjects::Paystub.from_pinwheel(paystub_json) }
    @http.get(PAYSTUBS_ENDPOINT, { q: { account: account_id } }).body
  end

  # TODO: refactor this into common function between argyle_service/pinwheel_service
  def build_url(endpoint)
    @http.build_url(endpoint).to_s
  end
end
