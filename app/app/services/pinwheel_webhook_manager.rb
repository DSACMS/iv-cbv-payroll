# This class manages argyle webhook subscriptions, and is intended for development environment setup only
class PinwheelWebhookManager
  def initialize
    @pinwheel = PinwheelService.new
  end

  ## may need to track the id
  # def remove_subscriptions_by_name(name)
  #   subscriptions = @pinwheel.fetch_webhook_subscriptions["results"]
  #   existing_webhook_subscriptions = subscriptions.find_all { |subscription| subscription["name"] == name }

  #   existing_webhook_subscriptions.each do |existing_webhook_subscription|
  #     puts "  Removing existing Argyle webhook subscription (url = #{existing_webhook_subscription["url"]})"
  #     @pinwheel.delete_webhook_subscription(existing_webhook_subscription["id"])
  #   end
  # end

  def create_subscription(tunnel_url)
    puts "  Registering Argyle webhooks for Ngrok tunnel..."
    response = @pinwheel.create_webhook_subscription([
      "account.added",
      "paystubs.added",
    ], URI.join(tunnel_url, "/webhooks/argyle/events"))
    new_webhook_subscription_id = response["data"]["id"]
    puts "  ✅ Set up Argyle webhooks (https://console.argyle.com/webhooks/#{new_webhook_subscription_id})"
  end
end
