class MixpanelEventTracker
  def self.for_request(request)
    new
  end

  def initialize
    @tracker = Mixpanel::Tracker.new(ENV["MIXPANEL_TOKEN"], MixpanelErrorHandler.new)
  end

  def track(event_type, request_attributes, attributes = {})
    distinct_id = ""
    tracker_attrs = {}
    flow_id = attributes.fetch(:cbv_flow_id, "")
    tracker_attrs = { cbv_flow_id: flow_id } if flow_id.present?

    if request_attributes.present?
      tracker_attrs.merge!({ "$ip": request_attributes.remote_ip })
    end

    # For caseworker events, use the "user_id" attribute as the distinct_id
    # For client events, use the "cbv_applicant_id" attribute as the distinct_id as it currently best
    # represents the concept of a unique user.
    user_id = attributes.fetch(:user_id, "")
    applicant_id = attributes.fetch(:cbv_applicant_id, "")
    if user_id.present?
      distinct_id = "caseworker-#{user_id}"
    elsif applicant_id.present?
      distinct_id = "applicant-#{applicant_id}"
    end

    # This creates a profile for a distinct user
    @tracker.people.set(distinct_id, tracker_attrs) if distinct_id.present?

    start_time = Time.now
    Rails.logger.info "  Sending Mixpanel event #{event_type} with attributes: #{attributes}"
    @tracker.track(distinct_id, event_type, attributes)
    Rails.logger.info "    Mixpanel event sent in #{Time.now - start_time}"
  end
end
