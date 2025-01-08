class GenericEventTracker
  def self.for_request(request)
    url_params = request.params.slice("site_id", "locale")

    # Set these attributes as default (global) across all the tracked events.
    new(
      {
        mixpanel: MixpanelEventTracker.for_request(request),
        newrelic: NewRelicEventTracker.for_request(request)
      },
      {
        "$device_id" => request.session.id,
        "ip" => request.ip,
        "cbv_flow_id" => request.session[:cbv_flow_id],
        "site_id" => url_params["site_id"],
        "locale" => url_params["locale"],
        "user_agent" => request.headers["User-Agent"]
      }
    )
  end

  def initialize(trackers, default_attributes)
    @trackers = trackers
    @default_attributes = default_attributes
  end

  def track(event_type, request, attributes = {})
    MaybeLater.run {
      if request.present?
        device_detector = DeviceDetector.new(request.headers["User-Agent"])
        attributes[:device_name] = device_detector.device_name
        attributes[:device_type] = device_detector.device_type
        attributes[:browser] = device_detector.name
      end

      combined_attributes = attributes.with_defaults(@default_attributes).stringify_keys

      responses = @trackers.map do |service, tracker|
        begin
          tracker.track(event_type, request, combined_attributes)
        rescue StandardError => e
          raise unless Rails.env.production?
          Rails.logger.error "  Failed to track #{event_type} in #{service}: #{e.message}"
        end
      end

      responses
    }
  end
end
