# This class manages argyle webhook subscriptions, and is intended for development environment setup only
class ArgyleWebhookManager
  def initialize
    @argyle = ArgyleService.new
  end

  def remove_subscriptions_by_name(name)
    subscriptions = @argyle.fetch_webhook_subscriptions["results"]
    existing_webhook_subscriptions = subscriptions.find_all { |subscription| subscription["name"] == name }

    existing_webhook_subscriptions.each do |existing_webhook_subscription|
      puts "  Removing existing Argyle webhook subscription (url = #{existing_webhook_subscription["url"]})"
      @argyle.delete_webhook_subscription(existing_webhook_subscription["id"])
    end
  end

  def create_subscription(name, tunnel_url)
    puts "  Registering Argyle webhooks for Ngrok tunnel..."
    response = @argyle.create_webhook_subscription([
      "accounts.updated",
      "accounts.connected",
      "paystubs.added",
      "paystubs.updated",
      "paystubs.partially_synced",
      "paystubs.fully_synced"
    ], name, URI.join(tunnel_url, "/webhooks/argyle/events"), ENV["ARGYLE_WEBHOOK_SECRET"])
    new_webhook_subscription_id = response["id"]
    puts "  ✅ Set up Argyle webhooks (https://console.argyle.com/webhooks/#{new_webhook_subscription_id})"
  end
end
