Rails.application.config.to_prepare do
  Rails.application.config.webhooks_initialization_error = nil

  # Only run this when running the Rails server in development
  if Rails.env.development? && defined?(::Rails::Server)
    begin
      tunnels_json = Net::HTTP.get(URI("http://127.0.0.1:4040/api/tunnels"))
      tunnels = JSON.parse(tunnels_json)["tunnels"]
      tunnel_url = tunnels.first["public_url"]
      puts "Found ngrok tunnel at #{tunnel_url}!"

      subscription_name = ENV["USER"]
      raise "USER environment variable not specified" unless subscription_name.present?

      if ProviderSearchService::SUPPORTED_PROVIDERS.include?(:pinwheel)
        # Pinwheel webhooks setup
        pinwheel_webhooks = PinwheelWebhookManager.new
        pinwheel_webhooks.create_subscription_if_necessary(tunnel_url, subscription_name)
      end

      if ProviderSearchService::SUPPORTED_PROVIDERS.include?(:argyle)
        # Argyle webhooks setup
        argyle_webhooks = ArgyleWebhooksManager.new(logger: ActiveSupport::Logger.new(STDOUT))
        argyle_webhooks.create_subscriptions_if_necessary(tunnel_url, subscription_name)
      end
    rescue => ex
      Rails.application.config.webhooks_initialization_error = ex.message
      puts "🟥 Unable to configure webhooks for development: #{ex}"
      puts "🟥   in #{ex.backtrace.first}"
      puts ex.inspect
    end
  end
end
