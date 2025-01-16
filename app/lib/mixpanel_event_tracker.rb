class MixpanelEventTracker
  def self.for_request(request)
    new
  end

  def initialize
    @tracker = Mixpanel::Tracker.new(ENV["MIXPANEL_TOKEN"], MixpanelErrorHandler.new)
  end

  def track(event_type, request, attributes = {})
    start_time = Time.now

    # Use the "invitation_id" attribute as the distinct_id as it currently best
    # represents the concept of a unique user.
    invitation_id = attributes.fetch(:invitation_id, "")
    distinct_id = "invitation-#{invitation_id}" if distinct_id.present?
    attributes.merge!({:user_id => invitation_id})

    # MaybeLater tries to run this code after the request has finished
    MaybeLater.run {
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
