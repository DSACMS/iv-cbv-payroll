class Cbv::BaseController < ApplicationController
  before_action :set_cbv_flow, :ensure_cbv_flow_not_yet_complete, :prevent_back_after_complete
  helper_method :agency_url, :next_path, :get_comment_by_account_id, :current_site

  private

  def show_translate_button?
    true
  end

  def set_cbv_flow
    if params[:token].present?
      invitation = CbvFlowInvitation.find_by(auth_token: params[:token])
      if invitation.blank?
        return redirect_to(root_url, flash: { alert: t("cbv.error_invalid_token") })
      end
      if invitation.expired?
        return redirect_to(cbv_flow_expired_invitation_path(site_id: invitation.site_id))
      end
      if invitation.complete?
        return redirect_to(cbv_flow_expired_invitation_path(site_id: invitation.site_id))
      end

      @cbv_flow = CbvFlow.create_from_invitation(invitation)
      session[:cbv_flow_id] = @cbv_flow.id
      NewRelicEventTracker.track("ClickedCBVInvitationLink", {
        timestamp: Time.now.to_i,
        invitation_id: invitation.id,
        cbv_flow_id: @cbv_flow.id,
        site_id: @cbv_flow.site_id,
        seconds_since_invitation: (Time.now - invitation.created_at).to_i
      })
    elsif session[:cbv_flow_id]
      begin
        @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
      rescue ActiveRecord::RecordNotFound
        redirect_to root_url
      end
    else
      track_timeout_event()
      redirect_to root_url, flash: { slim_alert: { type: "info", message_html: t("cbv.error_missing_token_html") } }
    end
  end

  def ensure_cbv_flow_not_yet_complete
    return unless @cbv_flow && @cbv_flow.complete?

    redirect_to(cbv_flow_success_path)
  end

  def current_site
    return unless @cbv_flow.present? && @cbv_flow.site_id.present?

    @current_site ||= site_config[@cbv_flow.site_id]
  end

  def next_path
    case params[:controller]
    when "cbv/entries"
      cbv_flow_agreement_path
    when "cbv/agreements"
      cbv_flow_employer_search_path
    when "cbv/employer_searches"
      cbv_flow_synchronizations_path
    when "cbv/synchronizations"
      cbv_flow_payment_details_path
    when "cbv/missing_results"
      cbv_flow_summary_path
    when "cbv/payment_details"
      cbv_flow_add_job_path
    when "cbv/summaries"
      cbv_flow_success_path
    end
  end

  def pinwheel
    pinwheel_for(@cbv_flow)
  end

  def agency_url
    current_site&.agency_contact_website
  end

  def get_comment_by_account_id(account_id)
    @cbv_flow.additional_information[account_id] || { comment: nil, updated_at: nil }
  end

  def prevent_back_after_complete
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "#{1.year.ago}"
  end

  def track_timeout_event
    NewRelicEventTracker.track("ApplicantTimedOut", {
      timestamp: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      has_pinwheel_account: @has_pinwheel_account
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantTimedOut): #{ex}"
  end
end
