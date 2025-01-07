module NewRelicEventTracker
  def self.track(event_type, attributes = {})
    start_time = Time.now
    Rails.logger.info "  Sending New Relic event: #{event_type} with attributes: #{attributes}"
    response = NewRelic::Agent.record_custom_event(event_type, attributes)
    Rails.logger.info "  New Relic event sent in #{Time.now - start_time}s."
    response
  rescue StandardError => e
    Rails.logger.error "  Failed to send New Relic event: #{e.message}"
  end
end
