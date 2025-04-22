# The purpose of this class is to allow us to file events with multiple event providers at once
# If we no longer need to do this, it may be that this class has outlived its usefulness!
class GenericEventTracker
  def track(event_type, request, attributes = {})
    merged_attributes = attributes.with_defaults(prep_request_attributes(request))
    if request.present?
      request_data = { headers: { "User-Agent": request.headers["User-Agent"] }, remote_ip: request.remote_ip  }
    else
      request_data = nil
    end
    if ENV["ACTIVEJOB_ENABLED"] == "true"
      EventTrackingJob.perform_later(event_type, request_data, merged_attributes)
    else
      MaybeLater.run do
        EventTrackingJob.perform_now(event_type, request_data, merged_attributes)
      end
    end
  end

  private
  def prep_request_attributes(request)
    defaults = {}
    if request.present?
      url_params = request.params.slice("client_agency_id", "locale")

      defaults = {
        # Not setting device_id because Mixpanel fixates on that as the distinct_id, which we do not want
        ip: request.remote_ip,
        cbv_flow_id: request.session[:cbv_flow_id],
        client_agency_id: url_params["client_agency_id"],
        locale: url_params["locale"] || I18n.locale.to_s,
        user_agent: request.headers["User-Agent"]
      }
    end
    defaults
  end
end
