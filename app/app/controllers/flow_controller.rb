class FlowController < ApplicationController
  helper_method :next_path

  def set_generic_flow
    unless current_agency
      redirect_to "/404"
      return
    end

    @flow = create_flow_with_new_applicant
    @cbv_flow = @flow # Maintain for compatibility until all controllers are converted

    set_flow_session(@flow.id, flow_param)
    apply_launcher_overrides

    track_generic_link_clicked_event(@flow)
  end

  def next_path
    flow_navigator.next_path
  end

  def progress_calculator
    nil
  end

  def flow_navigator
    locales = Regexp.union(I18n.available_locales.map(&:to_s))

    case request.path
    when %r{^(/#{locales})?/activities}
      overall_progress_result = progress_calculator&.overall_result
      ActivityFlowNavigator.new(params, overall_progress_result: overall_progress_result)
    when %r{^(/#{locales})?/cbv}
      CbvFlowNavigator.new(params)
    else
      raise "flow_navigator called from unknown page #{request.path}!"
    end
  end

  private

  def create_flow_with_new_applicant
    applicant = CbvApplicant.create!(client_agency_id: current_agency.id)
    flow_class(flow_param).create(
      cbv_applicant: applicant,
      device_id: cookies.permanent.signed[:device_id],
      **flow_attributes_from_params
    )
  end

  def set_flow
    if params[:token].present?
      token = normalize_token(params[:token])
      invitation = invitation_class.find_by(auth_token: token)

      unless invitation
        return redirect_to(root_url, flash: { alert: invalid_token_message })
      end

      if invitation.expired?
        track_expired_event(invitation)
        return redirect_to(cbv_flow_expired_invitation_path(client_agency_id: invitation.client_agency_id))
      end

      @flow = flow_class(flow_param).create_from_invitation(
        invitation,
        cookies.permanent.signed[:device_id],
        params
      )
      @cbv_flow = @flow # Maintain for compatibility until all controllers are converted
      set_flow_session(@flow.id, flow_param)
      apply_launcher_overrides
      track_invitation_clicked_event(invitation, @flow)
    elsif session[:flow_id]
      begin
        @flow = flow_class.find(session[:flow_id])
        @cbv_flow = @flow # Maintain for compatibility until all controllers are converted
      rescue ActiveRecord::RecordNotFound
        reset_cbv_session!
        redirect_to root_url(cbv_flow_timeout: true)
      end
    else
      track_deeplink_without_cookie_event
      redirect_to root_url(cbv_flow_timeout: true), flash: { slim_alert: { type: "info", message_html: t("cbv.error_missing_token_html") } }
    end
  end

  def track_generic_link_clicked_event(flow)
    # Skip tracking this event for a specific user agent, since we tend
    # to get a ton of traffic from it during LA SMS sends
    return if request.user_agent&.match?(/go-http-client/i)

    event_logger.track(TrackEvent::ApplicantClickedGenericLink, request, {
      time: Time.now.to_i,
      cbv_applicant_id: flow.cbv_applicant_id,
      cbv_flow_id: flow.id, # TODO: Genericize/migrate key, it could be activity or cbv
      client_agency_id: flow.cbv_applicant.client_agency_id,
      origin: params[:origin]
    })
  end

  def track_deeplink_without_cookie_event
    event_logger.track(TrackEvent::ApplicantAccessedFlowWithoutCookie, request, {
      time: Time.now.to_i,
      client_agency_id: current_agency&.id
    })
  end

  def flow_attributes_from_params
    flow_class(flow_param).flow_attributes_from_params(params)
  end

  def apply_launcher_overrides
    return unless internal_environment?

    if params[:reporting_window_months].present?
      @flow.set_reporting_window_months!(params[:reporting_window_months])
    end

    if params[:renewal_required_months].present?
      @flow.set_required_month_count!(params[:renewal_required_months])
    end

    if params[:reporting_window_start].present?
      @flow.shift_reporting_window_start!(params[:reporting_window_start])
    end

    if params[:launcher_timeout].present?
      session[:launcher_timeout] = params[:launcher_timeout].to_i.minutes.to_i
    end
  end
end
