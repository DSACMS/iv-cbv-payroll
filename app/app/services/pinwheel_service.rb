# frozen_string_literal: true

require "faraday"

class PinwheelService
  PINWHEEL_VERSION = "2023-11-22"
  BASE_URL = "https://sandbox.getpinwheel.com"
  USERS_ENDPOINT = "/v1/accounts"
  USER_TOKENS_ENDPOINT = "/v1/link_tokens"
  ITEMS_ENDPOINT = "/v1/search"
  PAYSTUBS_ENDPOINT = "/paystubs"
  WEBHOOKS_ENDPOINT = "/v1/webhooks"

  def initialize(api_key = ENV["PINWHEEL_API_TOKEN"])
    raise "PINWHEEL_API_TOKEN environment variable is blank. Make sure you have the .env.local.local from 1Password." if api_key.blank?

    @api_key = api_key

    client_options = {
      request: {
        open_timeout: 5,
        timeout: 5
      },
      url: BASE_URL,
      headers: {
        "Content-Type" => "application/json",
        "Pinwheel-Version" => PINWHEEL_VERSION,
        "X-API-SECRET" => "#{@api_key}"
      }
    }
    @http = Faraday.new(client_options) do |conn|
      conn.response :raise_error
      conn.response :json, content_type: "application/json"
    end
  end

  def build_url(endpoint)
    @http.build_url(endpoint).to_s
  end

  def fetch_items(options)
    @http.get(build_url(ITEMS_ENDPOINT), options).body
  end

  def create_link_token(end_user_id:, response_type:, id:)
    @http.post(build_url(USER_TOKENS_ENDPOINT), {
      org_name: "Verify.gov",
      required_jobs: [ "paystubs", "employment", "income" ],
      end_user_id: end_user_id,
      skip_intro_screen: true,
      "#{response_type}_id": id
    }.to_json).body
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
