class Cbv::BaseController < FlowController
  ALPHANUMERIC_PREFIX_REGEXP = /^([a-zA-Z0-9]+)[^a-zA-Z0-9]*$/

  before_action :set_cbv_origin, :set_cbv_flow, :ensure_cbv_flow_not_yet_complete, :prevent_back_after_complete, :capture_page_view
  helper_method :agency_url, :next_path, :get_comment_by_account_id, :current_agency

  private

  def normalize_token(token)
    matches = ALPHANUMERIC_PREFIX_REGEXP.match(token)
    matches[1] if matches
  end

  def set_cbv_flow
    if params[:token].present?
      token = normalize_token(params[:token])
      invitation = CbvFlowInvitation.find_by(auth_token: token)

      unless invitation
        return redirect_to(root_url, flash: { alert: t("cbv.error_invalid_token") })
      end

      if invitation.expired?
        track_expired_event(invitation)
        return redirect_to(cbv_flow_expired_invitation_path(client_agency_id: invitation.client_agency_id))
      end

      @cbv_flow = CbvFlow.create_from_invitation(invitation, cookies.permanent.signed[:device_id])
      session[:cbv_flow_id] = @cbv_flow.id
      cookies.permanent.encrypted[:cbv_applicant_id] = @cbv_flow.cbv_applicant_id
      track_invitation_clicked_event(invitation, @cbv_flow)

    elsif session[:cbv_flow_id]
      begin
        @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
      rescue ActiveRecord::RecordNotFound
        reset_cbv_session!
        redirect_to root_url(cbv_flow_timeout: true)
      end
    else
      track_deeplink_without_cookie_event
      redirect_to root_url(cbv_flow_timeout: true), flash: { slim_alert: { type: "info", message_html: t("cbv.error_missing_token_html") } }
    end
  end

  def set_cbv_origin
    origin_param = params.fetch(:origin, "")
    if origin_param.present?
      # If we get a param, use it to overwrite the origin.
      # This helps us meet the state expectation that somebody who clicks a second link should switch to that origin in our tracking.
      origin = origin_param
    elsif origin_param.blank? and session[:cbv_origin].blank?
      # If we don't get a param, and if we don't already have an origin, regress to the default.
      # This preserves defaulting behavior.
      agency = agency_config[detect_client_agency_from_domain]
      origin = agency&.default_origin
    else
      # Otherwise, do not change the origin.
      # This allows LA /start to preserve the initial 'email' origin specified in our routes
      return
    end

    if origin.present?
      session[:cbv_origin] = origin.strip.downcase.gsub(/\s+/, "_").first(64)
    end
  end

  def ensure_cbv_flow_not_yet_complete
    return unless @cbv_flow && @cbv_flow.complete?

    redirect_to(cbv_flow_success_path)
  end

  def next_path
    case params[:controller]
    when "cbv/generic_links"
      cbv_flow_entry_path
    when "cbv/entries"
      cbv_flow_employer_search_path
    when "cbv/employer_searches"
      cbv_flow_synchronizations_path
    when "cbv/synchronizations"
      cbv_flow_payment_details_path
    when "cbv/missing_results"
      cbv_flow_applicant_information_path
    when "cbv/payment_details"
      cbv_flow_add_job_path
    when "cbv/other_jobs"
      cbv_flow_applicant_information_path
    when "cbv/applicant_informations"
      cbv_flow_summary_path
    when "cbv/summaries"
      cbv_flow_submits_path
    when "cbv/submits"
      cbv_flow_success_path
    end
  end

  def pinwheel
    pinwheel_for(@cbv_flow)
  end

  def argyle
    argyle_for(@cbv_flow)
  end

  def agency_url
    current_agency&.agency_contact_website
  end

  def get_comment_by_account_id(account_id)
    @cbv_flow.additional_information[account_id] || { comment: nil, updated_at: nil }
  end

  def prevent_back_after_complete
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "#{1.year.ago}"
  end

  def capture_page_view
    event_logger.track(TrackEvent::CbvPageView, request, {
      time: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      client_agency_id: @cbv_flow.client_agency_id,
      device_id: @cbv_flow.device_id,
      path: request.path
    })
  end

  def track_timeout_event
    event_logger.track(TrackEvent::ApplicantTimedOut, request, {
      time: Time.now.to_i,
      client_agency_id: current_agency&.id
    })
  end

  def track_deeplink_without_cookie_event
    event_logger.track(TrackEvent::ApplicantAccessedFlowWithoutCookie, request, {
      time: Time.now.to_i,
      client_agency_id: current_agency&.id
    })
  end

  def track_expired_event(invitation)
    event_logger.track(TrackEvent::ApplicantAccessedExpiredLinkPage, request, {
      invitation_id: invitation.id,
      cbv_applicant_id: invitation.cbv_applicant_id,
      client_agency_id: current_agency&.id,
      time: Time.now.to_i
    })
  end

  def track_invitation_clicked_event(invitation, cbv_flow)
    event_logger.track(TrackEvent::ApplicantClickedCBVInvitationLink, request, {
      time: Time.now.to_i,
      invitation_id: invitation.id,
      cbv_flow_id: cbv_flow.id,
      cbv_applicant_id: cbv_flow.cbv_applicant_id,
      client_agency_id: current_agency&.id,
      device_id: cbv_flow.device_id,
      seconds_since_invitation: (Time.now - invitation.created_at).to_i,
      household_member_count: count_unique_members(invitation),
      completed_reports_count: invitation.cbv_flows.completed.count,
      flows_started_count: invitation.cbv_flows.count,
      origin: session[:cbv_origin]
    })
  end

  def count_unique_members(invitation)
    return 1 if invitation.cbv_applicant.income_changes.blank?

    invitation.cbv_applicant.income_changes.map { |income_change| income_change.with_indifferent_access[:member_name] }.uniq.count
  end

  def ensure_payroll_account_linked
    return if @cbv_flow&.has_account_with_required_data?

    redirect_to cbv_flow_synchronization_failures_path
  end

  def reset_cbv_session!
    session[:cbv_flow_id] = nil
  end
end
