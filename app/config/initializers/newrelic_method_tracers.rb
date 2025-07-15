require "new_relic/agent/method_tracer"

Rails.application.config.to_prepare do
  Cbv::BaseController.class_eval do
    add_method_tracer :set_cbv_flow
    add_method_tracer :capture_page_view
  end
end
