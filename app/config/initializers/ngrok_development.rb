Rails.application.config.to_prepare do
  # Only run this when running the Rails server in development
  if Rails.env.development? && defined?(::Rails::Server)
    begin
      ngrok_url = ENV["DOCKERIZED"] ? "ngrok" : "127.0.0.1"
       tunnels_json = Net::HTTP.get(URI("http://#{ngrok_url}:4040/api/tunnels"))
      tunnels = JSON.parse(tunnels_json)["tunnels"]
      tunnel_url = tunnels.first["public_url"]
      puts "Found ngrok tunnel at #{tunnel_url}!"

      subscription_name = ENV["USER"]
      raise "USER environment variable not specified" unless subscription_name.present?

      pinwheel_webhooks = PinwheelWebhookManager.new
      pinwheel_webhooks.create_subscription_if_necessary(tunnel_url, subscription_name)
    rescue => ex
      puts "🟥 Unable to configure Ngrok for development: #{ex}"
      puts ex.inspect
    end
  end
end
