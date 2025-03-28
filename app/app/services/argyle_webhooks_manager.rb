# This class manages Argyle webhook subscriptions, and is intended for
# development environment setup only
#
# The webhooks will be registered in the Argyle environment listed under the
# "sandbox" site in site-config.yml.
class ArgyleWebhooksManager
  def initialize
    @sandbox_config = Rails.application.config.client_agencies["sandbox"]
    @argyle = ArgyleService.new(@sandbox_config.argyle_environment)
  end

  def existing_subscriptions_with_name(formatted_identifier_name)
    @subscriptions = @argyle.get_webhook_subscriptions["results"]
    @subscriptions.find_all { |subscription| subscription["name"] == formatted_identifier_name }
  end

  def remove_subscriptions(subscriptions)
    subscriptions.each do |subscription|
      puts "  Removing existing Argyle webhook subscription (url = #{subscription["url"]})"
      @argyle.delete_webhook_subscription(subscription["id"])
    end
  end

  def create_subscription_if_necessary(tunnel_url, name)
    receiver_url = URI.join(tunnel_url, "/webhooks/argyle/events").to_s
    subscriptions = existing_subscriptions_with_name(name)
    existing_subscription = subscriptions.find do |subscription|
      subscription["url"] == receiver_url && subscription["events"] == ArgyleService.get_webhook_events
    end

    if existing_subscription
      puts "  Existing Argyle webhook subscription found in Argyle #{@sandbox_config.argyle_environment}: #{existing_subscription["url"]}"
      remove_subscriptions(subscriptions.excluding(existing_subscription))

      existing_subscription["id"]
    else
      puts "  Registering Argyle webhooks for Ngrok tunnel in Argyle #{@sandbox_config.argyle_environment}..."
      response = @argyle.create_webhook_subscription(ArgyleService.get_webhook_events, receiver_url, name)
      new_webhook_subscription_id = response["id"]
      puts "  ✅ Set up Argyle webhook: #{new_webhook_subscription_id}"
      puts " Argyle webhook url: #{receiver_url}"

      new_webhook_subscription_id
    end
  end

  def format_identifier_hash(identifier)
    "ngrok_subscription_#{identifier}"
  end
end
