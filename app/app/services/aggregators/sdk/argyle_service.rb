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
        api_key_secret: ENV["ARGYLE_API_TOKEN_SANDBOX_SECRET"],
        webhook_secret: ENV["ARGYLE_SANDBOX_WEBHOOK_SECRET"]
      },
      production: {
        base_url: "https://api.argyle.com/v2",
        api_key_id: ENV["ARGYLE_API_TOKEN_ID"],
        api_key_secret: ENV["ARGYLE_API_TOKEN_SECRET"],
        webhook_secret: ENV["ARGYLE_WEBHOOK_SECRET"]
      }
    }

    # See: https://console.argyle.com/flows
    FLOW_ID = "BXSHLUUJ"

    EMPLOYER_SEARCH_ENDPOINT = "employer-search"
    PAYSTUBS_ENDPOINT = "paystubs"
    IDENTITIES_ENDPOINT = "identities"
    USERS_ENDPOINT = "users"
    USER_TOKENS_ENDPOINT = "user-tokens"
    ACCOUNTS_ENDPOINT = "accounts"
    EMPLOYMENTS_ENDPOINT = "employments"
    GIGS_ENDPOINT = "gigs"
    SHIFTS_ENDPOINT = "shifts"
    WEBHOOKS_ENDPOINT = "webhooks"

    attr_reader :webhook_secret

    def initialize(environment, api_key_id = nil, api_key_secret = nil, webhook_secret = nil)
      @environment = ENVIRONMENTS.fetch(environment.to_sym) { |env| raise KeyError.new("ArgyleService unknown environment: #{env}") }
      @api_key_id = api_key_id || @environment[:api_key_id]
      @api_key_secret = api_key_secret || @environment[:api_key_secret]
      @webhook_secret = webhook_secret || @environment[:webhook_secret]
      @base_url = @environment[:base_url]

      client_options = {
        request: {
          open_timeout: 5,
          timeout: 5,
          params_encoder: Faraday::FlatParamsEncoder
        },
        url: @base_url,
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
      @http.get(build_url(WEBHOOKS_ENDPOINT)).body
    end

    def create_webhook_subscription(events, url, name, config = {})
      payload = {
        events: events,
        name: name,
        url: url,
        config: config.presence,
        secret: @webhook_secret
      }

      @http.post(build_url(WEBHOOKS_ENDPOINT), payload.to_json).body
    end

    def delete_webhook_subscription(id)
      @http.delete(build_url("#{WEBHOOKS_ENDPOINT}/#{id}")).body
    end

    # Search for Argyle employer
    # https://docs.argyle.com/api-reference/employer-search#list
    def employer_search(query, status = %w[healthy issues])
      @http.get(build_url(EMPLOYER_SEARCH_ENDPOINT), { q: query, status: status }).body
    end

    # https://docs.argyle.com/api-reference/users#retrieve
    def fetch_user_api(user:)
      @http.get(build_url("#{USERS_ENDPOINT}/#{user}")).body
    end

    # https://docs.argyle.com/api-reference/identities#list
    def fetch_identities_api(account: nil, user: nil, employment: nil, limit: 10)
      params = {
        account: account,
        user: user,
        employment: employment,
        limit: limit
      }.compact
      @http.get(build_url(IDENTITIES_ENDPOINT), params).body
    end

    # https://docs.argyle.com/api-reference/accounts#list
    # Note: we get all account information from the identities endpoint, so this is not
    # currently used.
    def fetch_accounts_api(user: nil, item: nil, ongoing_refresh_status: nil, limit: 10)
      valid_statuses = %w[idle enabled disabled]
      if ongoing_refresh_status && !valid_statuses.include?(ongoing_refresh_status)
        raise ArgumentError, "Invalid ongoing_refresh_status: #{ongoing_refresh_status}"
      end

      params = {
        user: user,
        item: item,
        ongoing_refresh_status: ongoing_refresh_status,
        limit: limit }.compact

      @http.get(build_url(ACCOUNTS_ENDPOINT), params).body
    end

    # https://docs.argyle.com/api-reference/paystubs#list
    def fetch_paystubs_api(
      account: nil,
      user: nil,
      employment: nil,
      from_start_date: nil,
      to_start_date: nil,
      limit: 200
    )
      params = {
        account: account,
        user: user,
        employment: employment,
        from_start_date: from_start_date,
        to_start_date: to_start_date,
        limit: limit }.compact
      page_response = @http.get(build_url(PAYSTUBS_ENDPOINT), params).body
      raise "Pagination not implemented" if page_response["next"].present?
      page_response
    end

    def create_user(cbv_flow_end_user_id = nil)
      params = cbv_flow_end_user_id.present? ? { external_id: cbv_flow_end_user_id } : {}
      @http.post(build_url(USERS_ENDPOINT), params.to_json).body
    end

    # https://docs.argyle.com/api-reference/user-tokens#create
    def create_user_token(user_id)
      @http.post(build_url(USER_TOKENS_ENDPOINT), { user: user_id }.to_json).body
    end

    # https://docs.argyle.com/api-reference/gigs#list
    def fetch_gigs_api(account: nil, user: nil,
                       from_start_datetime: nil,
                       to_start_datetime: nil, limit: 200)
      params = {
        account: account,
        user: user,
        from_start_datetime: from_start_datetime,
        to_start_datetime: to_start_datetime,
        limit: limit }.compact

      @http.get(GIGS_ENDPOINT, params).body
    end

    # https://docs.argyle.com/api-reference/shifts#list
    def fetch_shifts_api(**params)
      @http.get(SHIFTS_ENDPOINT, params).body
    end

    # https://docs.argyle.com/api-reference/employments#list
    # Note: we get all employment information from the identities endpoint, so this is not
    # currently used.
    def fetch_employments_api(user: nil, account: nil)
      raise ArgumentError if user.nil? && account.nil?
      params = { user: user, account: account }.compact
      @http.get(build_url(EMPLOYMENTS_ENDPOINT), params).body
    end

    def build_url(endpoint)
      @http.build_url(endpoint).to_s
    end
  end
end
