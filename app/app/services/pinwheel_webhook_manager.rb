# This class manages pinwheel webhook subscriptions, and is intended for
# development environment setup only
#
# The webhooks will be registered in the Pinwheel environment listed under the
# "sandbox" site in site-config.yml. Any sites in diffeent environments will
# not work. (i.e. if the sandbox site is set to Pinwheel environment "sandbox",
# then any sites with Pinwheel environment "development" will not have their
# webhooks configured.)
class PinwheelWebhookManager
  WEBHOOK_EVENTS = %w[
    account.added
    paystubs.added
    paystubs.fully_synced
    employment.added
    income.added
  ]

  def initialize
    @sandbox_config = Rails.application.config.sites["sandbox"]
    @pinwheel = PinwheelService.new(@sandbox_config.pinwheel_api_token, @sandbox_config.pinwheel_environment)
  end

  def existing_subscriptions(name)
    subscriptions = @pinwheel.fetch_webhook_subscriptions["data"]
    subscriptions.find_all { |subscription| subscription["url"].end_with?(format_identifier_hash(name)) }
  end

  def remove_subscriptions(subscriptions)
    subscriptions.each do |subscription|
      puts "  Removing existing Pinwheel webhook subscription (url = #{subscription["url"]})"
      @pinwheel.delete_webhook_subscription(subscription["id"])
    end
  end

  def create_subscription_if_necessary(tunnel_url, name)
    receiver_url = URI.join(tunnel_url, "/webhooks/pinwheel/events", format_identifier_hash(name)).to_s
    subscriptions = existing_subscriptions(name)
    existing_subscription = subscriptions.find do |subscription|
      subscription["url"] == receiver_url && subscription["enabled_events"] == WEBHOOK_EVENTS
    end

    if existing_subscription
      puts "  Existing Pinwheel webhook subscription found in Pinwheel #{@sandbox_config.pinwheel_environment}: #{existing_subscription["url"]}"
      remove_subscriptions(subscriptions.excluding(existing_subscription))
    else
      remove_subscriptions(subscriptions)

      puts "  Registering Pinwheel webhooks for Ngrok tunnel in Pinwheel #{@sandbox_config.pinwheel_environment}..."
      response = @pinwheel.create_webhook_subscription(WEBHOOK_EVENTS, receiver_url)
      new_webhook_subscription_id = response["data"]["id"]
      puts "  ✅ Set up Pinwheel webhook: #{new_webhook_subscription_id}"
    end
  end

  def format_identifier_hash(identifier)
    "#subscription_name=#{identifier}"
  end
end
