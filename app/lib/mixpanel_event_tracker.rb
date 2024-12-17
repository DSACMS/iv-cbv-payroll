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
    @tracker = Mixpanel::Tracker.new(ENV["MIXPANEL_TOKEN"])
    @default_attributes = default_attributes
  end

  def track(event_type, attributes = {})
    start_time = Time.now
    Rails.logger.info "Sending Mixpanel event: #{event_type} with attributes: #{attributes}"
    combined_attributes = attributes.with_defaults(@default_attributes).stringify_keys

    # Use the "invitation_id" attribute as the distinct_id as it currently best
    # represents the concept of a unique user.
    distinct_id = combined_attributes.fetch("invitation_id", "")
    distinct_id.prepend("invitation-") if distinct_id.present?

    response = @tracker.track(distinct_id, event_type, combined_attributes)
    Rails.logger.info "Mixpanel event sent in #{Time.now - start_time}"
    response
  rescue StandardError => e
    raise unless Rails.env.production?

    Rails.logger.error "Failed to send Mixpanel event: #{e.message}"
  end
end
