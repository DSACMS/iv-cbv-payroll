# frozen_string_literal: true

require "faraday"
require "fileutils"
require "json"

module Aggregators::Sdk
  class ArgyleService
    include ApiService

    # Configure the configuration mappings with lambdas for lazy evaluation.
    # This allows us to evaluate the environment variables only when they are needed
    # and mock the environment variables for testing.
    # Defining the configuration as a constant means that the configuration is evaluated
    # when the class is loaded, not when the instance is created.
    configure(
      {
        sandbox: -> {
          {
            api_key_id: ENV["ARGYLE_SANDBOX_API_TOKEN_ID"],
            api_key_secret: ENV["ARGYLE_SANDBOX_API_TOKEN_SECRET"],
            webhook_secret: ENV["ARGYLE_SANDBOX_WEBHOOK_SECRET"],
            base_url: "https://api-sandbox.argyle.com/v2",
            environment: "sandbox"
          }
        },
        production: -> {
          {
            api_key_id: ENV["ARGYLE_API_TOKEN_ID"],
            api_key_secret: ENV["ARGYLE_API_TOKEN_SECRET"],
            webhook_secret: ENV["ARGYLE_WEBHOOK_SECRET"],
            base_url: "https://api.argyle.com/v2",
            environment: "production"
          }
        },
        default: :sandbox
      }
    )

    ITEMS_ENDPOINT = "items"
    PAYSTUBS_ENDPOINT = "paystubs"
    IDENTITIES_ENDPOINT = "identities"
    USERS_ENDPOINT = "users"
    ACCOUNTS_ENDPOINT = "accounts"
    EMPLOYMENTS_ENDPOINT = "employments"
    WEBHOOKS_ENDPOINT = "webhooks"

    def initialize(environment, api_key_id = nil, api_key_secret = nil, webhook_secret = nil)
      @configuration = get_configuration(environment)

      # prioritize the constructor args over the environment variables
      @configuration[:api_key_id] = api_key_id if api_key_id
      @configuration[:api_key_secret] = api_key_secret if api_key_secret
      @configuration[:webhook_secret] = webhook_secret if webhook_secret
      @webhook_secret = @configuration[:webhook_secret]

      client_options = {
        request: {
          open_timeout: 5,
          timeout: 5,
          params_encoder: Faraday::FlatParamsEncoder
        },
        url: @configuration[:base_url],
        headers: {
          "Content-Type" => "application/json"
        }
      }
      @http = Faraday.new(client_options) do |conn|
        conn.set_basic_auth @configuration[:api_key_id], @configuration[:api_key_secret]
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

    def create_webhook_subscription(events, url, name, webhook_secret = @configuration[:webhook_secret])
      payload = {
        events: events,
        name: name,
        url: url,
        secret: webhook_secret
      }

      make_request(:post, WEBHOOKS_ENDPOINT, payload)
    end

    def delete_webhook_subscription(id)
      make_request(:delete, "#{WEBHOOKS_ENDPOINT}/#{id}")
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
    def fetch_identities_api(account: nil, user: nil, employment: nil, limit: 10)
      params = {
        account: account,
        user: user,
        employment: employment,
        limit: limit }.compact
      make_request(:get, IDENTITIES_ENDPOINT, params)
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

      make_request(:get, ACCOUNTS_ENDPOINT, params)
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
      page_response = make_request(:get, PAYSTUBS_ENDPOINT, params)
      raise "Pagination not implemented" if page_response["next"].present?
      page_response
    end

    def create_user(cbv_flow_end_user_id = nil)
      params = cbv_flow_end_user_id.present? ? { external_id: cbv_flow_end_user_id } : {}
      make_request(:post, USERS_ENDPOINT, params)
    end

    # https://docs.argyle.com/api-reference/employments#list
    # Note: we get all employment information from the identities endpoint, so this is not
    # currently used.
    def fetch_employments_api(user: nil, account: nil)
      raise ArgumentError if user.nil? && account.nil?
      params = { user: user, account: account }.compact
      make_request(:get, EMPLOYMENTS_ENDPOINT, params)
    end
  end
end
