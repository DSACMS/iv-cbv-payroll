module NonProductionAccessible
  extend ActiveSupport::Concern

  # Returns true if running in development, test, or demo environment
  # Use this to gate features that should only be available in non-production environments
  def is_not_production?
    Rails.env.development? || Rails.env.test? || ENV["DOMAIN_NAME"]&.match?(/demo\.divt\.app$/)
  end
end
