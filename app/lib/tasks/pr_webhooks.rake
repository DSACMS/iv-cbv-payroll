namespace :pr_webhooks do
  desc "Remove Pinwheel/Argyle webhook subscriptions for a PR environment"
  task destroy: :environment do
    pr_number = ENV["PR_NUMBER"]
    abort("PR_NUMBER must be set") if pr_number.blank?

    subscription_name = "pr-#{pr_number}"

    if Rails.application.config.supported_providers.include?(:pinwheel)
      manager = PinwheelWebhookManager.new
      subs = manager.existing_subscriptions(subscription_name)
      manager.remove_subscriptions(subs)
      Rails.logger.info "Removed #{subs.size} Pinwheel webhook subscription(s) for #{subscription_name}"
    end

    if Rails.application.config.supported_providers.include?(:argyle)
      manager = ArgyleWebhooksManager.new(logger: Rails.logger)
      # ArgyleWebhooksManager#create_subscriptions_if_necessary creates 4
      # subscriptions per name (one base + 3 partial/include-resource variants).
      [
        subscription_name,
        "#{subscription_name}-partial",
        "#{subscription_name}-partial-six-months",
        "#{subscription_name}-include-resource"
      ].each do |name|
        subs = manager.existing_subscriptions_with_name(name)
        manager.remove_subscriptions(subs)
        Rails.logger.info "Removed #{subs.size} Argyle webhook subscription(s) for #{name}"
      end
    end
  end
end
