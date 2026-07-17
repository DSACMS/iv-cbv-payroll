if ENV["DD_TRACE_ENABLED"] == "true"
  require "datadog"

  Datadog.configure do |config|
    config.version = ENV.fetch("IMAGE_TAG")
    config.tracing.instrument :rails
  end
end
