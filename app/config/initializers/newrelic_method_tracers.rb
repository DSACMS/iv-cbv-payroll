require "new_relic/agent/method_tracer"

Rails.application.config.to_prepare do
  # Add custom metric tracking for a few possibly slow endpoints
  NewRelicEventTracker.class_eval do
    class << self
      add_method_tracer :track, "Custom/NewRelicEventTracker/track"
    end
  end

  Cbv::BaseController.class_eval do
    add_method_tracer :set_cbv_flow
    add_method_tracer :capture_page_view
  end
end
