# This class manages argyle webhook subscriptions, and is intended for development environment setup only
class PinwheelWebhookManager
  def initialize
    @pinwheel = PinwheelService.new
  end

  ## may need to track the id
  def remove_ngrok_subscriptions_by_subscription_name(name)
    subscriptions = @pinwheel.fetch_webhook_subscriptions["data"]
    ngrok_subscriptions = subscriptions.find_all { |subscription| subscription["url"].match(format_identifier_hash(name)) }

    ngrok_subscriptions.each do |subscription|
      puts "  Removing existing Argyle webhook subscription (url = #{subscription["url"]})"
      @pinwheel.delete_webhook_subscription(subscription["id"])
    end
  end

  def create_subscription(tunnel_url, name)
    puts "  Registering Argyle webhooks for Ngrok tunnel..."
    response = @pinwheel.create_webhook_subscription([
      "account.added",
      "paystubs.added"
    ], URI.join(tunnel_url, "/webhooks/pinwheel/events", format_identifier_hash(name)))
    new_webhook_subscription_id = response["data"]["id"]
    puts "  ✅ Set up Argyle webhooks (https://console.argyle.com/webhooks/#{new_webhook_subscription_id})"
  end

  def format_identifier_hash(identifier)
    "#subscription_name=#{identifier}"
  end
end
