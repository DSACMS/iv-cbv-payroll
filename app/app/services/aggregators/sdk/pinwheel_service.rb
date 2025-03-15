# frozen_string_literal: true

require "faraday"
module Aggregators::Sdk
  class PinwheelService
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

    TOP_PROVIDERS = [
      {
        id: "5becff90-1e35-450a-8995-13ac411e749b",
        name: "ADP",
        response_type: "platform",
        logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/adpPortal.svg"
      },
      {
        id: "5965580e-380f-4b86-8a8a-7278c77f73cb",
        name: "Workday",
        response_type: "platform",
        logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/cfmpw.png"
      },
      {
        id: "3f812c04-ac83-495b-99ca-7ec7d56dc68b",
        name: "Paycom",
        response_type: "platform",
        logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/paycom.svg"
      },
      {
        id: "9a4e213b-aeed-4cb2-aace-696bcd2b1e0d",
        name: "Paychex",
        response_type: "platform",
        logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/paychex.svg"
      },
      {
        id: "913170d1-393c-4f35-8c23-df3133ce7529",
        name: "Paylocity",
        response_type: "platform",
        logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/paylocity.png"
      },
      {
        id: "b0b655f8-4ae6-4d09-a60f-1df9a2a1fd16",
        name: "Paycor",
        response_type: "platform",
        logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/paycor.png"
      }
    ]
    TOP_EMPLOYERS = [
      {
        id: "d66e65b2-536d-4b2d-b73c-f6addd66c0f4",
        name: "Amazon",
        response_type: "employer",
        logo_url: "https://cdn.getpinwheel.com/assets/employers/logos/Amazon.svg"
      },
      {
        id: "737d833a-1b68-44f7-92ae-3808374cb459",
        name: "DoorDash",
        response_type: "employer",
        logo_url: "https://cdn.getpinwheel.com/assets/employers/logos/DoorDash%20%28Dasher%29.svg"
      },
      {
        id: "91063607-2b4a-4c8e-8045-a543f01b8b09",
        name: "Uber",
        response_type: "employer",
        logo_url: "https://cdn.getpinwheel.com/assets/employers/logos/Uber%20%28Driver%29.svg"
      },
      {
        id: "70b2bed2-ada8-49ec-99c2-691cc7d28df6",
        name: "Lyft",
        response_type: "employer",
        logo_url: "https://cdn.getpinwheel.com/assets/employers/logos/Lyft%20%28Driver%29.svg"
      },
      {
        id: "9f7ddcaf-cbc5-4bd2-b701-d40c67389eae",
        name: "Instacart",
        response_type: "employer",
        logo_url: "https://cdn.getpinwheel.com/assets/employers/logos/Instacart%20%28Full%20Service%20Shopper%29.svg"
      },
      {
        id: "adde7178-43cd-4cc6-8857-65dfc54a77e8",
        name: "TaskRabbit",
        response_type: "employer",
        logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/taskRabbit.png"
      }
    ]

    def initialize(environment, api_key = nil)
      @api_key = api_key || ENVIRONMENTS.fetch(environment.to_sym)[:api_key]
      @environment = ENVIRONMENTS.fetch(environment.to_sym) { |env| raise KeyError.new("Aggregators::Sdk::PinwheelService unknown environment: #{env}") }

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

    def fetch_report_data(account:)
      return unless pinwheel_account.job_succeeded?("employment") and
      pinwheel_account.job_succeeded?("income") and
      pinwheel_account.job_succeeded?("identity") and
      pinwheel_account.job_succeeded?("paystubs")

      Aggregators::ResponseObjects::AggregatorReport.new(
        identity: fetch_identity(account_id: account),
        employments: fetch_employment(account_id: account),
        incomes: fetch_income(account_id: account),
        paystubs: fetch_paystubs(account_id: account)
      )
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
      json = @http.get(build_url("#{ACCOUNTS_ENDPOINT}/#{account_id}/paystubs"), params).body
      json["data"].map { |paystub_json| Aggregators::ResponseObjects::Paystub.from_pinwheel(paystub_json) }
    end

    def fetch_employment(account_id:)
      json = @http.get(build_url("#{ACCOUNTS_ENDPOINT}/#{account_id}/employment")).body

      Aggregators::ResponseObjects::Employment.from_pinwheel(json["data"])
    end

    def fetch_identity(account_id:)
      json = @http.get(build_url("#{ACCOUNTS_ENDPOINT}/#{account_id}/identity")).body

      Aggregators::ResponseObjects::Identity.from_pinwheel(json["data"])
    end

    def fetch_income(account_id:)
      json = @http.get(build_url("#{ACCOUNTS_ENDPOINT}/#{account_id}/income")).body

      Aggregators::ResponseObjects::Income.from_pinwheel(json["data"])
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
  end
end
