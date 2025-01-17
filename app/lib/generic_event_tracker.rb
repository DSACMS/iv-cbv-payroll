# The purpose of this class is to allow us to file events with multiple event providers at once
# If we no longer need to do this, it may be that this class has outlived its usefulness!
class GenericEventTracker
  def self.for_request(request)
    defaults = {}
    if request.present?
      url_params = request.params.slice("site_id", "locale")
      defaults = {
        # Not setting device_id because Mixpanel fixates on that as the distinct_id, which we do not want
        :ip => request.ip,
        :cbv_flow_id => request.session[:cbv_flow_id],
        :site_id => url_params["site_id"],
        :locale => url_params["locale"],
        :user_agent => request.headers["User-Agent"]
      }
    end

    # Set these attributes as default (global) across all the tracked events.
    new(
      {
        mixpanel: MixpanelEventTracker.for_request(request),
        newrelic: NewRelicEventTracker.for_request(request)
      },
      defaults
    )
  end

  def initialize(trackers, default_attributes)
    @trackers = trackers
    @default_attributes = default_attributes
  end

  def track(event_type, request, attributes = {})
    if request.present?
      device_detector = DeviceDetector.new(request.headers["User-Agent"])
      attributes[:device_name] = device_detector.device_name
      attributes[:device_type] = device_detector.device_type
      attributes[:browser] = device_detector.name
    end

    combined_attributes = attributes.with_defaults(@default_attributes)

    @trackers.map do |service, tracker|
      begin
        tracker.track(event_type, request, combined_attributes)
      rescue StandardError => e
        raise unless Rails.env.production?
        Rails.logger.error "  Failed to track #{event_type} in #{service}: #{e.message}"
      end
    end
  end
end
