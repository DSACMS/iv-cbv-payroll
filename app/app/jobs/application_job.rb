class ApplicationJob < ActiveJob::Base
  retry_on Exception, wait: :polynomially_longer, attempts: 5

  def event_logger
    @event_logger ||= GenericEventTracker.new
  end

  def with_flow_tags(flow, &block)
    return yield unless ENV.fetch("STRUCTURED_LOGGING_ENABLED", "false") == "true"

    tags = {
      flow_id: flow.id,
      flow_type: flow.class.name,
      invitation_id: flow.invitation_id,
      cbv_applicant_id: flow.cbv_applicant_id,
      client_agency_id: flow.cbv_applicant.client_agency_id,
      device_id: flow.device_id
    }

    Rails.logger.tagged(tags, &block)
  end

  rescue_from(Exception) do |error|
    trace_metadata = {}
    if NewRelic::Agent::Tracer.current_transaction
      trace_metadata = {
        "trace.id" => NewRelic::Agent::Tracer.current_trace_id,
        "span.id" => NewRelic::Agent::Tracer.current_span_id,
        "entity.guid" => NewRelic::Agent.config[:'entity_guid']
      }
    end

    NewRelic::Agent.record_custom_event("SolidQueueJobFailed", {
      job_class: (self.class.name || "UnknownJob"),
      job_id: self.job_id,
      queue_name: (self.queue_name || "default"),
      failed_at: Time.now.to_s,
      error_class: error.class.name,
      error_message: error.message,
      executions: self.executions,
      max_attempts: 5
    }.merge(trace_metadata))
    raise error
  end
end
