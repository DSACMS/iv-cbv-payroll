if ENV["DD_TRACE_ENABLED"] == "true"
  require "datadog"

  Datadog.configure do |config|
    config.version = ENV["IMAGE_TAG"]
    config.tracing.instrument :rails
  end
end
