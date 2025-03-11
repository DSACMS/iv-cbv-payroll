# frozen_string_literal: true

require "faraday"
require "fileutils"
require "json"

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
  USERS_ENDPOINT = "users"
  ACCOUNTS_ENDPOINT = "accounts"
  EMPLOYMENTS_ENDPOINT = "employments"
  GIGS_ENDPOINT= "gigs"

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
    @http.get(ITEMS_ENDPOINT, { q: query }).body
  end

  # https://docs.argyle.com/api-reference/users#retrieve
  def fetch_user_api(user:)
    @http.get(build_url("#{USERS_ENDPOINT}/#{user}")).body
  end

  # https://docs.argyle.com/api-reference/identities#list
  def fetch_identities_api(**params)
    # todo: paginate
    @http.get(IDENTITIES_ENDPOINT, params).body
  end

  # https://docs.argyle.com/api-reference/accounts#list
  def fetch_accounts_api(**params)
    # TODO: paginate
    # json["data"].map { |paystub_json| ResponseObjects::Paystub.from_pinwheel(paystub_json) }
    @http.get(ACCOUNTS_ENDPOINT, params).body
  end

  # https://docs.argyle.com/api-reference/paystubs#list
  def fetch_paystubs_api(**params)
    # TODO: paginate
    @http.get(PAYSTUBS_ENDPOINT, params).body
  end

  # https://docs.argyle.com/api-reference/paystubs#list
  def fetch_gigs_api(**params)
    # TODO: paginate
    @http.get(GIGS_ENDPOINT, params).body
  end

  def create_user
    @http.post(USERS_ENDPOINT).body
  end

  # https://docs.argyle.com/api-reference/employments#list
  def fetch_employments_api(**params)
    # json["data"].map { |paystub_json| ResponseObjects::Paystub.from_pinwheel(paystub_json) }
    @http.get(EMPLOYMENTS_ENDPOINT, params).body
  end

  # TODO: refactor this into common function between argyle_service/pinwheel_service
  def build_url(endpoint)
    @http.build_url(endpoint).to_s
  end

  def store_mock_response(responsePayload:, folderName: "other", fileName:)
    FileUtils.mkdir_p "spec/support/fixtures/argyle/#{folderName}"

    File.open("spec/support/fixtures/argyle/#{folderName}/#{fileName}.json", "wb") do
      |f| f.puts(JSON.pretty_generate(responsePayload))
    end
  end

  # Only for use in sandbox environment for test mocking
  def fetch__and_store_mock_data_for_user(argyle_user_id:, folderName:)
    store_mock_response(
      folderName: folderName,
      fileName: "request_user",
      responsePayload: fetch_user_api(user: argyle_user_id))

    store_mock_response(
      folderName: folderName,
      fileName: "request_identity",
      responsePayload: fetch_identities_api(user: argyle_user_id))

    store_mock_response(
      folderName: folderName,
      fileName: "request_employment",
      responsePayload: fetch_employment_api(user: argyle_user_id))

    store_mock_response(
      folderName: folderName,
      fileName: "request_accounts",
      responsePayload: fetch_accounts_api(user: argyle_user_id))

    store_mock_response(
      folderName: folderName,
      fileName: "request_paystubs",
      responsePayload: fetch_paystubs_api(user: argyle_user_id))
  end
end
