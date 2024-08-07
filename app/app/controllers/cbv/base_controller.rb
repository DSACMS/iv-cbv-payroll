class Cbv::BaseController < ApplicationController
  include Cbv::PaymentsHelper
  before_action :set_cbv_flow
  helper_method :agency_url, :next_path, :get_comment_by_account_id, :current_site

  private

  def set_cbv_flow
    if params[:token].present?
      invitation = CbvFlowInvitation.find_by(auth_token: params[:token])
      if invitation.blank?
        return redirect_to(root_url, flash: { alert: t("cbv.error_invalid_token") })
      end
      if invitation.expired?
        return redirect_to(cbv_flow_expired_invitation_path)
      end

      @cbv_flow = invitation.cbv_flow || CbvFlow.create_from_invitation(invitation)
      NewRelicEventTracker.track("ClickedCBVInvitationLink", {
        timestamp: Time.now.to_i,
        invitation_id: invitation.id,
        cbv_flow_id: @cbv_flow.id
      })
    elsif session[:cbv_flow_id]
      begin
        @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
      rescue ActiveRecord::RecordNotFound
        return redirect_to root_url
      end
    else
      # TODO: Restrict ability to enter the flow without a valid token
      @cbv_flow = CbvFlow.create(site_id: "sandbox")
    end

    session[:cbv_flow_id] = @cbv_flow.id
  end

  def current_site
    return unless @cbv_flow.present? && @cbv_flow.site_id.present?

    site_config[@cbv_flow.site_id]
  end

  def set_payments(account_id = nil)
    payments = account_id.nil? ? fetch_payroll : fetch_payroll_for_account_id(account_id)

    @payments = parse_payments(payments)
  end

  def next_path
    case params[:controller]
    when "cbv/entries"
      cbv_flow_agreement_path
    when "cbv/agreements"
      cbv_flow_employer_search_path
    when "cbv/employer_searches"
      cbv_flow_payment_details_path
    when "cbv/payment_details"
      cbv_flow_add_job_path
    when "cbv/summaries"
      cbv_flow_share_path
    when "cbv/shares"
      cbv_flow_success_path
    end
  end

  def pinwheel
    pinwheel_for(@cbv_flow)
  end

  def fetch_payroll
    end_user_account_ids = pinwheel.fetch_accounts(end_user_id: @cbv_flow.pinwheel_end_user_id)["data"].map { |account| account["id"] }

    end_user_account_ids.map do |account_id|
      fetch_payroll_for_account_id account_id
    end.flatten
  end

  def fetch_payroll_for_account_id(account_id)
    pinwheel.fetch_paystubs(account_id: account_id, from_pay_date: 90.days.ago.strftime("%Y-%m-%d"))["data"]
  end

  def agency_url
    "https://www.nyc.gov/site/hra/help/snap-application-frequently-asked-questions.page"
  end

  def get_comment_by_account_id(account_id)
    @cbv_flow.additional_information[account_id] || { comment: nil, updated_at: nil }
  end
end
