class FlowController < ApplicationController
  ALPHANUMERIC_PREFIX_REGEXP = /^([a-zA-Z0-9]+)[^a-zA-Z0-9]*$/

  def set_generic_flow
    @flow, is_new_session = find_or_create_flow
    @cbv_flow = @flow # Maintain for compatibility until all controllers are converted

    set_flow_session(@flow.id, flow_param)
    cookies.permanent.encrypted[:cbv_applicant_id] = @flow.cbv_applicant_id

    track_generic_link_clicked_event(@flow, is_new_session)
  end

  private

  def find_or_create_flow
    existing_applicant = find_existing_applicant_from_cookie
    if existing_applicant && existing_applicant.client_agency_id == current_agency&.id
      create_flow_with_existing_applicant(existing_applicant)
    else
      create_flow_with_new_applicant
    end
  end

  def create_flow_with_existing_applicant(applicant)
    applicant.reset_applicant_attributes
    flow = flow_class.create(cbv_applicant: applicant, device_id: cookies.permanent.signed[:device_id])
    [ flow, false ]
  end

  def create_flow_with_new_applicant
    flow = flow_class.create(
      cbv_applicant: CbvApplicant.create(client_agency_id: current_agency&.id),
      device_id: cookies.permanent.signed[:device_id]
    )
    [ flow, true ]
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

      @flow = flow_class.create_from_invitation(invitation, cookies.permanent.signed[:device_id])
      @cbv_flow = @flow # Maintain for compatibility until all controllers are converted
      set_flow_session(@flow.id, flow_param)
      cookies.permanent.encrypted[:cbv_applicant_id] = @flow.cbv_applicant_id
      track_invitation_clicked_event(invitation, @flow)
    elsif session[cbv_flow_symbol]
      begin
        @flow = flow_class.find(session[cbv_flow_symbol])
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

  def find_existing_applicant_from_cookie
    applicant_id = cookies.encrypted[:cbv_applicant_id]
    return nil unless applicant_id.present?

    CbvApplicant.find_by(id: applicant_id)
  end

  def track_generic_link_clicked_event(flow, is_new_session)
    # Skip tracking this event for a specific user agent, since we tend
    # to get a ton of traffic from it during LA SMS sends
    return if request.user_agent&.match?(/go-http-client/i)

    event_logger.track(TrackEvent::ApplicantClickedGenericLink, request, {
      time: Time.now.to_i,
      cbv_applicant_id: flow.cbv_applicant_id,
      cbv_flow_id: flow.id, # TODO: Genericize/migrate key, it could be activity or cbv
      client_agency_id: flow.cbv_applicant.client_agency_id,
      device_id: flow.device_id,
      origin: params[:origin],
      is_new_session: is_new_session
    })
  end

  def track_deeplink_without_cookie_event
    event_logger.track(TrackEvent::ApplicantAccessedFlowWithoutCookie, request, {
      time: Time.now.to_i,
      client_agency_id: current_agency&.id
    })
  end

  def normalize_token(token)
    matches = ALPHANUMERIC_PREFIX_REGEXP.match(token)
    matches[1] if matches
  end
end
