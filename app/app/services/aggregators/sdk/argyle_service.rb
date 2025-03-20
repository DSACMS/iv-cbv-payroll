# frozen_string_literal: true

require "faraday"
require "fileutils"
require "json"

module Aggregators::Sdk
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
    def fetch_user_api(user:)
      @http.get(build_url("#{USERS_ENDPOINT}/#{user}")).body
    end

    # https://docs.argyle.com/api-reference/identities#list
    def fetch_identities_api(account: nil, user: nil,
                             employment: nil, limit: 10)
      params = {
        account: account,
        user: user,
        employment: employment,
        limit: limit }.compact
      # todo: paginate
      @http.get(IDENTITIES_ENDPOINT, params).body
    end

    # https://docs.argyle.com/api-reference/accounts#list
    # Note: we get all account information from the identities endpoint, so this is not
    # currently used.
    def fetch_accounts_api(user: nil, item: nil, ongoing_refresh_status: nil, limit: 10)
      valid_statuses = [ "idle", "enabled", "disabled" ]
      if ongoing_refresh_status && !valid_statuses.include?(ongoing_refresh_status)
        raise ArgumentError, "Invalid ongoing_refresh_status: #{ongoing_refresh_status}"
      end

      params = {
        user: user,
        item: item,
        ongoing_refresh_status: ongoing_refresh_status,
        limit: limit }.compact

      # TODO: paginate
      # json["data"].map { |paystub_json| Aggregators::ResponseObjects::Paystub.from_pinwheel(paystub_json) }
      @http.get(ACCOUNTS_ENDPOINT, params).body
    end

    # https://docs.argyle.com/api-reference/paystubs#list
    def fetch_paystubs_api(account: nil, user: nil,
                           employment: nil, from_start_date: nil,
                           to_start_date: nil, limit: 200)
      params = {
        account: account,
        user: user,
        employment: employment,
        from_start_date: from_start_date,
        to_start_date: to_start_date,
        limit: limit }.compact
      page_response = @http.get(PAYSTUBS_ENDPOINT, params).body
      raise "Pagination not implemented" if page_response.has_value?("next")
      page_response
    end

    def create_user
      @http.post(USERS_ENDPOINT).body
    end

    # https://docs.argyle.com/api-reference/employments#list
    # Note: we get all employment information from the identities endpoint, so this is not
    # currently used.
    def fetch_employments_api(user: nil, account: nil)
      raise ArgumentError if user.nil? && account.nil?
      params = { user: user, account: account }.compact
      @http.get(EMPLOYMENTS_ENDPOINT, params).body
    end

    # TODO: refactor this into common function between argyle_service/pinwheel_service
    def build_url(endpoint)
      @http.build_url(endpoint).to_s
    end
  end
end
