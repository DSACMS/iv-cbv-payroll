require_relative "newrelic_event_map.rb"

class MixpanelEventTracker
  def self.for_request(request)
    url_params = request.params.slice("site_id", "locale")

    # Set these attributes as default (global) across all the tracked events.
    new(
      "$device_id" => request.session.id,
      "ip" => request.ip,
      "cbv_flow_id" => request.session[:cbv_flow_id],
      "site_id" => url_params["site_id"],
      "locale" => url_params["locale"],
      "user_agent" => request.headers["User-Agent"],
    )
  end

  def initialize(default_attributes)
    @tracker = Mixpanel::Tracker.new(ENV["MIXPANEL_TOKEN"], MyErrorHandler.new)
    @default_attributes = default_attributes
  end

  def track(event_type, request, attributes = {})
    if request.present?
      device_detector = DeviceDetector.new(request.headers["User-Agent"])
      attributes[:device_name] = device_detector.device_name
      attributes[:device_type] = device_detector.device_type
      attributes[:browser] = device_detector.name
    end

    combined_attributes = attributes.with_defaults(@default_attributes).stringify_keys

    Rails.logger.info "Sending event #{event_type} with attributes: #{attributes}"

    # Use the "invitation_id" attribute as the distinct_id as it currently best
    # represents the concept of a unique user.
    distinct_id = combined_attributes.fetch("invitation_id", "")
    distinct_id = "invitation-#{distinct_id}" if distinct_id.present?

    start_time = Time.now
    begin
      response = @tracker.track(distinct_id, event_type, combined_attributes)
      Rails.logger.info "  Mixpanel event sent in #{Time.now - start_time}"
    rescue StandardError => e
      raise unless Rails.env.production?

      Rails.logger.error "  Failed to send Mixpanel event: #{e.message}"
    end

    start_time = Time.now

    # Map to the old NewRelic event name if present, otherwise just send NewRelic the event_type name
    newrelic_event_type = $newrelic_event_map[event_type]
    if not newrelic_event_type.present?
      newrelic_event_type = event_type
    end

    begin
      response = NewRelic::Agent.record_custom_event(newrelic_event_type, combined_attributes)
      Rails.logger.info "  NewRelic event sent in #{Time.now - start_time}"
    rescue StandardError => e
      raise unless Rails.env.production?

      Rails.logger.error "  Failed to send NewRelic event: #{e.message}"
    end

    response
  rescue StandardError => e
    raise unless Rails.env.production?

    Rails.logger.error "  Failed to send event: #{e.message}"
  end

  class MyErrorHandler < Mixpanel::ErrorHandler

    def handle(error)
      raise error unless Rails.env.production?
      Rails.logger.error "  MixpanelErrorTracker:#{error.inspect}\n Backtrace: #{error.backtrace}"
    end

  end
end

