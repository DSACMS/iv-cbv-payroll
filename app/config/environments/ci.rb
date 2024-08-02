require_relative "production"

Rails.application.configure do
  config.public_file_server.enabled = true
  config.force_ssl = false

  logger = ActiveSupport::Logger.new($stdout)
  logger.formatter = config.log_formatter
  config.logger = ActiveSupport::TaggedLogging.new(logger)
end
