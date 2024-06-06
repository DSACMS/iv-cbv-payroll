class CbvFlowsController < ApplicationController
  before_action :set_cbv_flow

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

    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "#{@cbv_flow.id}", template: "cbv_flows/summary"
      end
    end
  end

  def share
  end

  def reset
    session[:cbv_flow_id] = nil
    session[:argyle_user_token] = nil
    redirect_to root_url
  end

  private

  def set_cbv_flow
    if session[:cbv_flow_id]
      begin
        @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
      rescue ActiveRecord::RecordNotFound
        return redirect_to root_url
      end
    elsif params[:token].present?
      invitation = CbvFlowInvitation.find_by(auth_token: params[:token])
      return redirect_to root_url if invitation.blank?

      @cbv_flow = invitation.cbv_flow || CbvFlow.create_from_invitation(invitation)
    else
      # TODO: Restrict ability to enter the flow without a valid token
      @cbv_flow = CbvFlow.create
    end

    session[:cbv_flow_id] = @cbv_flow.id
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

  def fetch_and_store_pinwheel_token
    return session[:pinwheel_user_token] if session[:pinwheel_user_token].present?

    user_token = provider.create_link_token(@cbv_flow.id).body["data"]
    @cbv_flow.update(pinwheel_token_id: user_token["id"])
    session[:pinwheel_user_token] = user_token["user_token"]

    user_token["token"]
  end

  def fetch_employers(query = "")
    request_params = {
      q: query,
      supported_jobs: ["paystubs"]
    }

    provider.fetch_items(request_params)["data"]
  end

  def fetch_payroll
    provider.fetch_paystubs(user: @cbv_flow.argyle_user_id)["results"]
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
