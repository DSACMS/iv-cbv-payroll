# Register Pinwheel/Argyle webhook subscriptions for per-PR review apps.
#
# Each PR environment has its own database schema (see PR #1440), so webhooks
# sent to dev/demo (where subscriptions are registered globally) would not
# reach PR-env-created CbvFlow records. Without a dedicated subscription,
# `Cbv::SynchronizationsController` hangs forever waiting for
# `payroll_account.has_fully_synced?` to flip.
#
# Mirrors `ngrok_development.rb` but for production-mode containers running
# on PR review apps. Teardown happens via `rake pr_webhooks:destroy`, invoked
# by `bin/destroy-pr-environment`.
Rails.application.config.to_prepare do
  Rails.application.config.pr_env_webhooks_initialization_error = nil

  domain = ENV["DOMAIN_NAME"]
  pr_match = domain&.match(/\Ap-(\d+)\.navapbc\.cloud\z/)

  if Rails.env.production? && pr_match && defined?(::Rails::Server)
    begin
      pr_number = pr_match[1]
      receiver_base_url = "https://#{domain}"
      subscription_name = "pr-#{pr_number}"

      Rails.logger.info "Registering webhooks for PR environment ##{pr_number} at #{receiver_base_url}"

      if Rails.application.config.supported_providers.include?(:pinwheel)
        PinwheelWebhookManager.new
          .create_subscription_if_necessary(receiver_base_url, subscription_name)
      end

      if Rails.application.config.supported_providers.include?(:argyle)
        ArgyleWebhooksManager.new(logger: Rails.logger)
          .create_subscriptions_if_necessary(receiver_base_url, subscription_name)
      end
    rescue => ex
      Rails.application.config.pr_env_webhooks_initialization_error = ex.message
      Rails.logger.error "🟥 Unable to configure webhooks for PR environment: #{ex}"
      Rails.logger.error "🟥   in #{ex.backtrace.first}"
    end
  end
end
