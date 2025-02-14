module CbvEventTracking
  extend ActiveSupport::Concern

  included do
    helper_method :current_cbv_flow
    private :current_agency
  end

  private

  def track_event(event_name, request, event_attributes = {})
    # Ensure all keys are symbols
    event_attributes = event_attributes.to_h.deep_transform_keys(&:to_sym)

    base_attributes = {
      browser: request.browser,
      device_name: request.device_name,
      device_type: request.device_type,
      ip: request.ip,
      user_agent: request.user_agent,
      client_agency_id: current_agency&.id,
      language: I18n.locale,
      locale: request.params[:locale] || I18n.locale,
      timestamp: Time.now.to_i
    }

    # Merge in CBV flow attributes if available
    if current_cbv_flow
      base_attributes.merge!(
        cbv_flow_id: current_cbv_flow.id,
        cbv_applicant_id: current_cbv_flow.cbv_applicant_id,
        invitation_id: current_cbv_flow.cbv_flow_invitation_id,
        flow_started_seconds_ago: (Time.now - current_cbv_flow.created_at).to_i
      )
    end

    # Let event-specific attributes override base attributes
    combined_attributes = base_attributes.merge(event_attributes)

    event_logger.track(event_name, request, combined_attributes)
  end

  def current_cbv_flow
    return unless session[:cbv_flow_id]
    @current_cbv_flow ||= CbvFlow.find_by(id: session[:cbv_flow_id])
  end

  def event_attributes
    return {} unless current_cbv_flow
    {
      cbv_flow_id: current_cbv_flow.id,
      cbv_applicant_id: current_cbv_flow.cbv_applicant_id,
      invitation_id: current_cbv_flow.cbv_flow_invitation_id,
      flow_started_seconds_ago: (Time.now - current_cbv_flow.created_at).to_i
    }
  end
end
