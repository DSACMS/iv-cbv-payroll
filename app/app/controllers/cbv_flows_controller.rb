class CbvFlowsController < ApplicationController
  before_action :set_cbv_flow
  before_action :set_payments, only: [:summary, :share]

  def entry
  end

  def employer_search
    @query = search_params[:query]
    @employers = @query.blank? ? [] : fetch_employers(@query)
  end

  def summary
    if request.patch?
      @cbv_flow.update(summary_update_params)
      return redirect_to next_path
    end

    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "#{@cbv_flow.id}", template: "cbv_flows/summary"
      end
    end
  end

  def share
    # replace with actual caseworker_email
    email_address = ENV["SLACK_TEST_EMAIL"]
    ApplicantMailer.with(email_address: email_address, cbv_flow: @cbv_flow, payments: @payments).caseworker_summary_email.deliver_now
  end

  def reset
    session[:cbv_flow_id] = nil
    redirect_to root_url
  end

  private

  def set_cbv_flow
    if params[:token].present?
      invitation = CbvFlowInvitation.find_by(auth_token: params[:token])
      if invitation.blank?
        return redirect_to(root_url, flash: { alert: t("cbv_flows.entry.error_invalid_token") })
      end

      @cbv_flow = invitation.cbv_flow || CbvFlow.create_from_invitation(invitation)
    elsif session[:cbv_flow_id]
      begin
        @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
      rescue ActiveRecord::RecordNotFound
        return redirect_to root_url
      end
    else
      # TODO: Restrict ability to enter the flow without a valid token
      @cbv_flow = CbvFlow.create
    end

    session[:cbv_flow_id] = @cbv_flow.id
  end

  def set_payments
    @payments = fetch_payroll.map do |payment|
      {
        employer: payment["employer"],
        amount: payment["net_pay"].to_i,
        start: payment["paystub_period"]["start_date"],
        end: payment["paystub_period"]["end_date"],
        hours: payment["hours"],
        rate: payment["rate"]
      }
    end
  end

  def next_path
    case params[:action]
    when "entry"
      cbv_flow_employer_search_path
    when "employer_search"
      cbv_flow_summary_path
    when "summary"
      cbv_flow_share_path
    when "share"
      root_url
    end
  end

  helper_method :next_path

  def fetch_employers(query = "")
    request_params = {
      q: query,
      supported_jobs: [ "paystubs" ]
    }

    provider.fetch_items(request_params)["data"]
  end

  def fetch_payroll
    account_ids = provider.fetch_accounts(end_user_id: @cbv_flow.pinwheel_end_user_id)["data"].map { |account| account["id"] }

    account_ids.map do |account_id|
      provider.fetch_paystubs(account_id: account_id)["data"]
    end.flatten
  end

  def provider
    PinwheelService.new
  end

  def search_params
    params.permit(:query)
  end

  def summary_update_params
    params.fetch(:cbv_flow, {}).permit(:additional_information)
  end
end
