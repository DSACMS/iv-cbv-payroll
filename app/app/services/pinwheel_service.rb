# frozen_string_literal: true

require "faraday"

class PinwheelService
  include ApiResponseLocalizer

  ENVIRONMENTS = {
    sandbox: {
      base_url: "https://sandbox.getpinwheel.com",
      api_key: ENV["PINWHEEL_API_TOKEN_SANDBOX"]
    },
    development: {
      base_url: "https://development.getpinwheel.com",
      api_key: ENV["PINWHEEL_API_TOKEN_DEVELOPMENT"]
    },
    production: {
      base_url: "https://api.getpinwheel.com",
      api_key: ENV["PINWHEEL_API_TOKEN_PRODUCTION"]
    }
  }

  PINWHEEL_VERSION = "2023-11-22"
  ACCOUNTS_ENDPOINT = "/v1/accounts"
  PLATFORMS_ENDPOINT = "/v1/platforms"
  USER_TOKENS_ENDPOINT = "/v1/link_tokens"
  ITEMS_ENDPOINT = "/v1/search"
  WEBHOOKS_ENDPOINT = "/v1/webhooks"
  END_USERS = "/v1/end_users"

  def initialize(environment, api_key = nil)
    @api_key = api_key || ENVIRONMENTS.fetch(environment.to_sym)[:api_key]
    @environment = ENVIRONMENTS.fetch(environment.to_sym) { |env| raise KeyError.new("PinwheelService unknown environment: #{env}") }

    client_options = {
      request: {
        open_timeout: 5,
        timeout: 5,
        # Pinwheel requires repeated params (i.e. `{ foo: [1, 2, 3] }`) to
        # be serialized as `?foo=1&foo=2&foo=3`:
        params_encoder: Faraday::FlatParamsEncoder
      },
      url: @environment[:base_url],
      headers: {
        "Content-Type" => "application/json",
        "Pinwheel-Version" => PINWHEEL_VERSION,
        "X-API-SECRET" => "#{@api_key}"
      }
    }
    @http = Faraday.new(client_options) do |conn|
      conn.response :raise_error
      conn.response :json, content_type: "application/json"
      conn.response :logger,
        Rails.logger,
        headers: true,
        bodies: true,
        log_level: :debug
    end
  end

  def build_url(endpoint)
    @http.build_url(endpoint).to_s
  end

  def fetch_items(options)
    @http.get(build_url(ITEMS_ENDPOINT), options).body
  end

  def fetch_accounts(end_user_id:)
    @http.get(build_url("#{END_USERS}/#{end_user_id}/accounts")).body
  end

  def fetch_paystubs(account_id:, **params)
    @http.get(build_url("#{ACCOUNTS_ENDPOINT}/#{account_id}/paystubs"), params).body
  end

  def fetch_employment(account_id:)
    @http.get(build_url("#{ACCOUNTS_ENDPOINT}/#{account_id}/employment")).body
  end

  def fetch_identity(account_id:)
    @http.get(build_url("#{ACCOUNTS_ENDPOINT}/#{account_id}/identity")).body
  end

  def fetch_income_metadata(account_id:)
    @http.get(build_url("#{ACCOUNTS_ENDPOINT}/#{account_id}/income")).body
  end

  def fetch_platform(platform_id:)
    @http.get(build_url("#{PLATFORMS_ENDPOINT}/#{platform_id}")).body
  end

  def create_link_token(end_user_id:, response_type:, id:, language:)
    params = {
      org_name: I18n.t("shared.pilot_name"),
      required_jobs: [ "paystubs" ],
      end_user_id: end_user_id,
      skip_intro_screen: true,
      language: language
    }

    case response_type.presence
    when "employer"
      params["employer_id"] = id
    when "platform"
      params["platform_id"] = id
    when nil
      # do nothing
    else
      raise "Invalid `response_type`: #{response_type}"
    end

    @http.post(build_url(USER_TOKENS_ENDPOINT), params.to_json).body
  end

  def fetch_webhook_subscriptions
    @http.get(build_url(WEBHOOKS_ENDPOINT)).body
  end

  def delete_webhook_subscription(id)
    webhook_url = URI.join(build_url(WEBHOOKS_ENDPOINT) + "/", id)
    @http.delete(webhook_url).body
  end

  def create_webhook_subscription(events, url)
    @http.post(build_url(WEBHOOKS_ENDPOINT), {
      enabled_events: events,
      url: url,
      status: "active",
      version: PINWHEEL_VERSION
    }.to_json).body
  end

  def generate_signature_digest(timestamp, raw_body)
    msg = "v2:#{timestamp}:#{raw_body}"
    digest = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      @api_key.encode("utf-8"),
      msg
    )
    "v2=#{digest}"
  end

  def verify_signature(signature, generated_signature)
    ActiveSupport::SecurityUtils.secure_compare(signature, generated_signature)
  end

  localize_methods :fetch_items, :fetch_accounts, :fetch_paystubs,
                   :fetch_employment, :fetch_identity, :fetch_income_metadata
end
