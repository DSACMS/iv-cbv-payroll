class MixpanelEventTracker
  def self.for_request(request)
    new
  end

  def initialize
    @tracker = Mixpanel::Tracker.new(ENV["MIXPANEL_TOKEN"], MixpanelErrorHandler.new)
  end

  def track(event_type, request, attributes = {})
    # Use the "invitation_id" attribute as the distinct_id as it currently best
    # represents the concept of a unique user.
    invitation_id = attributes.fetch(:invitation_id, "")
    distinct_id = ""
    if invitation_id.present?
      distinct_id = "applicant-#{invitation_id}"

      # This creates a profile for a distinct user
      flow_id = attributes.fetch(:cbv_flow_id, "")

      tracker_attrs =  { cbv_flow_id: flow_id }
      if request.present?
        tracker_attrs.merge!({ "$ip": request.remote_ip })
      end

      @tracker.people.set(distinct_id, tracker_attrs)
    end

    # MaybeLater tries to run this code after the request has finished
    MaybeLater.run {
      start_time = Time.now
      Rails.logger.info "  Sending Mixpanel event #{event_type} with attributes: #{attributes}"
      begin
        @tracker.track(distinct_id, event_type, attributes)
        Rails.logger.info "    Mixpanel event sent in #{Time.now - start_time}"
      rescue StandardError => e
        raise unless Rails.env.production?

        Rails.logger.error "    Failed to send Mixpanel event: #{e.message}"
      end
    }
  rescue StandardError => e
    raise unless Rails.env.production?

    Rails.logger.error "    Failed to send event: #{e.message}"
  end
end
