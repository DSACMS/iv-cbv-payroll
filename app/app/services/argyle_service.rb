# frozen_string_literal: true

require "faraday"
require "fileutils"

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
  # https://docs.argyle.com/api-reference/items#list
  def items(query = nil)
    @http.get(ITEMS_ENDPOINT, { q: query }).body
  end

  # https://docs.argyle.com/api-reference/users#retrieve
  def fetch_user(user:)
    @http.get(build_url("users/#{user}")).body
  end

  # https://docs.argyle.com/api-reference/identities#retrieve
  def fetch_identity(**params)
    # todo: paginate
    @http.get("identities", params).body
  end

  # https://docs.argyle.com/api-reference/accounts#list
  def fetch_accounts(**params)
    # TODO: paginate
    # json["data"].map { |paystub_json| ResponseObjects::Paystub.from_pinwheel(paystub_json) }
    @http.get("accounts", params).body
  end

  # https://docs.argyle.com/api-reference/paystubs#list
  def fetch_paystubs(**params)
    # TODO: paginate
    json = @http.get(PAYSTUBS_ENDPOINT, params).body
    json["results"].map { |paystub_json| ResponseObjects::Paystub.from_argyle(paystub_json) }
  end

  # https://docs.argyle.com/api-reference/employments#list
  def fetch_employment(**params)
    # json["data"].map { |paystub_json| ResponseObjects::Paystub.from_pinwheel(paystub_json) }
    @http.get("employments", params).body
  end

  # TODO: refactor this into common function between argyle_service/pinwheel_service
  def build_url(endpoint)
    @http.build_url(endpoint).to_s
  end

  def _tmp_fetch_all(user_id:, user_name:)
    FileUtils.mkdir_p "spec/support/fixtures/argyle/#{user_id}"

    # File.open("spec/support/fixtures/argyle/#{user_id}/request_user.json", "wb") {
    #  |f| f.puts(fetch_user(user: user_id).to_json)
    # }

    # File.open("spec/support/fixtures/argyle/#{user_id}/request_identity.json", "wb") {
    # |f| f.puts(fetch_identity(account: user_id).to_json)
    # }

    # File.open("spec/support/fixtures/argyle/#{user_id}/request_employment.json", "wb") {
    #  |f| f.puts(fetch_employment(account: ).to_json)
    # }

    # File.open("spec/support/fixtures/argyle/#{user_id}/request_accounts.json", "wb") {
    #  |f| f.puts(fetch_accounts(account: ).to_json)
    # }
    File.open("spec/support/fixtures/argyle/#{user_name}/request_paystubs.json", "wb") {
      |f| f.puts(fetch_paystubs(user: user_id).to_json)
      # , from_start_date: "2025-02-20", to_start_date: "2025-02-26").to_json)
    }
  end

  def create_user
    @http.post("users").body
  end
end
