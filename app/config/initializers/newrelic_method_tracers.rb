require "new_relic/agent/method_tracer"

# this is where we determine which methods new relic should be tracing
Rails.application.config.to_prepare do
  Cbv::BaseController.class_eval do
    add_method_tracer :set_cbv_flow
    add_method_tracer :capture_page_view
  end
end
