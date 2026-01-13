class Cbv::BaseController < FlowController
  before_action :set_cbv_origin, :set_flow, :ensure_cbv_flow_not_yet_complete, :prevent_back_after_complete, :capture_page_view
  before_action :check_if_pilot_ended
  around_action :append_log_tags, if: -> { ENV.fetch("STRUCTURED_LOGGING_ENABLED", "false") == "true" }
  helper_method :agency_url, :get_comment_by_account_id

  private

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
    return unless @flow && @flow.complete?

    redirect_to(cbv_flow_success_path)
  end

  def pinwheel
    pinwheel_for(@flow)
  end

  def argyle
    argyle_for(@flow)
  end

  def agency_url
    current_agency&.agency_contact_website
  end

  def get_comment_by_account_id(account_id)
    @flow.additional_information[account_id] || { comment: nil, updated_at: nil }
  end

  def prevent_back_after_complete
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "#{1.year.ago}"
  end

  def check_if_pilot_ended
    @pilot_ended = current_agency&.pilot_ended
    redirect_to root_path if @pilot_ended && !home_page?
  end

  def append_log_tags(&block)
    tags = {}

    if @flow.present?
      tags.merge!(
        cbv_flow_id: @flow.id,
        invitation_id: @flow.cbv_flow_invitation_id,
        cbv_applicant_id: @flow.cbv_applicant_id,
        client_agency_id: @flow.cbv_applicant.client_agency_id,
        device_id: @flow.device_id,
      )
    end

    Rails.logger.tagged(tags, &block)
  end

  def capture_page_view
    event_logger.track(TrackEvent::CbvPageView, request, {
      time: Time.now.to_i,
      cbv_flow_id: @flow.id,
      invitation_id: @flow.invitation_id,
      cbv_applicant_id: @flow.cbv_applicant_id,
      client_agency_id: @flow.cbv_applicant.client_agency_id,
      device_id: @flow.device_id,
      path: request.path
    })
  end

  def track_timeout_event
    event_logger.track(TrackEvent::ApplicantTimedOut, request, {
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
    return if @flow&.has_account_with_required_data?

    redirect_to cbv_flow_synchronization_failures_path
  end

  def flow_param
    :cbv
  end

  def entry_path
    root_url
  end

  def invitation_class
    CbvFlowInvitation
  end

  def invalid_token_message
    t("cbv.error_invalid_token")
  end
end
