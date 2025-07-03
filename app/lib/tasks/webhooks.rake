namespace :webhooks do
  desc "Register webhooks"
  task register: :environment do
    puts "Registering webhooks..."

    subscription_name = Rails.env
    domain_name = ENV["DOMAIN_NAME"]

    unless domain_name.present?
      raise "DOMAIN_NAME environment variable not specified"
    end

    if Rails.application.config.supported_providers.include?(:pinwheel)
      puts "  Registering Pinwheel webhooks..."
      pinwheel_webhooks = PinwheelWebhookManager.new
      pinwheel_webhooks.create_subscription_if_necessary(domain_name, subscription_name)
    end

    if Rails.application.config.supported_providers.include?(:argyle)
      puts "  Registering Argyle webhooks..."
      argyle_webhooks = ArgyleWebhooksManager.new(logger: ActiveSupport::Logger.new(STDOUT))
      argyle_webhooks.create_subscriptions_if_necessary(domain_name, subscription_name)
    end

    puts "✅ Done."
  end
end
