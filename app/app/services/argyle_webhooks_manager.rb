# This class subscribes to Argyle webhooks, and is intended for regular use in
# the development environment only.
#
# It may also be useful in demo/production when converting a client agency
# config to run in that environment for the first time, e.g. if we just
# configured AZ DES to use the production Argyle configuration and need to set
# up the webhooks, we could run:
#
#   a = ArgyleWebhooksManager.new("az_des")
#   a.create_subscriptions_if_necessary(ENV["DOMAIN_NAME"], "production")
#
# The webhooks will be registered based on the Argyle environment specified in the
# "az_des" configuration in client-agency-config.yml.
class ArgyleWebhooksManager
  def initialize(agency_id: "sandbox", logger: STDOUT)
    @agency_config = Rails.application.config.client_agencies[agency_id]
    @argyle = Aggregators::Sdk::ArgyleService.new(@agency_config.argyle_environment)
    @logger = logger
  end

  def existing_subscriptions_with_name(name)
    existing_subscriptions.find_all { |subscription| subscription["name"] == name }
  end

  def remove_subscriptions(subscriptions)
    subscriptions.each do |subscription|
      @logger.puts "  Removing existing Argyle webhook subscription (url = #{subscription["url"]})"
      @argyle.delete_webhook_subscription(subscription["id"])
    end
  end

  def create_subscriptions_if_necessary(tunnel_url, name)
    raise "You must provide a name value!" unless name.present?

    receiver_url = URI.join(tunnel_url, "/webhooks/argyle/events").to_s

    create_subscription(receiver_url, name, :non_partial)
    create_subscription(receiver_url, "#{name}-partial", :partial)
  end

  private

  def existing_subscriptions
    @_existing_subscriptions ||= @argyle.get_webhook_subscriptions["results"]
  end

  def create_subscription(receiver_url, name, webhooks_type)
    subscriptions = existing_subscriptions_with_name(name)
    existing_subscription = subscriptions.find do |subscription|
      subscription["url"] == receiver_url &&
        subscription["events"] == Aggregators::Webhooks::Argyle.get_webhook_events(type: webhooks_type)
    end

    if existing_subscription
      @logger.puts "  Existing Argyle webhook subscription found in Argyle #{@agency_config.argyle_environment}: #{existing_subscription["url"]}"
      remove_subscriptions(subscriptions.excluding(existing_subscription))

      existing_subscription["id"]
    else
      remove_subscriptions(subscriptions)

      @logger.puts "  Registering Argyle webhooks for Ngrok tunnel in Argyle #{@agency_config.argyle_environment}..."
      response = @argyle.create_webhook_subscription(
        Aggregators::Webhooks::Argyle.get_webhook_events(type: webhooks_type),
        receiver_url,
        name,
        webhook_subscription_config(webhooks_type)
      )
      new_webhook_subscription_id = response["id"]
      @logger.puts "  ✅ Set up Argyle webhook: #{new_webhook_subscription_id}"
      @logger.puts " Argyle webhook url: #{receiver_url}"

      new_webhook_subscription_id
    end
  end

  def webhook_subscription_config(webhooks_type)
    return nil if webhooks_type == :non_partial

    # Configure the `paystubs.partially_synced` and `gigs.partially_synced`
    # webhooks to trigger early based on the largest value of pay_income_days.
    #
    # We may want to eventually create webhook subscriptions for every value of
    # pay_income_days, so that agencies with shorter amounts of required data
    # can benefit from a quicker sync.
    largest_pay_income_days = Rails.application.config.client_agencies.client_agency_ids.map do |agency_id|
      Rails.application.config.client_agencies[agency_id].pay_income_days
    end.compact.max

    { days_synced: largest_pay_income_days }
  end
end
