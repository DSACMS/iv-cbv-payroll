# frozen_string_literal: true

Rails.application.config.to_prepare do
  redis_url = CloudGovConfig.dig "aws-elasticache-redis", "credentials", "uri"
  if redis_url.present?
    Sidekiq.configure_server do |config|
      config.redis = {url: redis_url, ssl: true}
    end

    Sidekiq.configure_client do |config|
      config.redis = {url: redis_url, ssl: true}
    end
  end
end
