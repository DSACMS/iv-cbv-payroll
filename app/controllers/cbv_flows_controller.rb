class CbvFlowsController < ApplicationController
  USER_TOKEN_ENDPOINT = "https://api-sandbox.argyle.com/v2/users"
  ITEMS_ENDPOINT = "https://api-sandbox.argyle.com/v2/items"
  PAYSTUBS_ENDPOINT = "https://api-sandbox.argyle.com/v2/paystubs?user="

  before_action :set_cbv_flow

  def entry
  end

  def employer_search
    @argyle_user_token = fetch_and_store_argyle_token
    @query = search_params[:query]
    @employers = @query.blank? ? [] : fetch_employers(@query)
  end

  def summary
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
        render pdf: "#{@cbv_flow.id}", template: 'cbv_flows/summary'
      end
    end
  end

  def reset
    session[:cbv_flow_id] = nil
    session[:argyle_user_token] = nil
    redirect_to root_url
  end

  private

  def set_cbv_flow
    if session[:cbv_flow_id]
      @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    else
      # TODO: This case_number would be provided by the case worker when they send the initial invite
      @cbv_flow = CbvFlow.create(case_number: "ABC1234")
      session[:cbv_flow_id] = @cbv_flow.id
    end
  end

  def next_path
    case params[:action]
    when "entry"
      cbv_flow_employer_search_path
    when "employer_search"
      cbv_flow_summary_path
    when "summary"
      root_url
    end
  end
  helper_method :next_path

  def fetch_and_store_argyle_token
    return session[:argyle_user_token] if session[:argyle_user_token].present?

    user_token = provider.create_user

    @cbv_flow.update(argyle_user_id: user_token['id'])
    session[:argyle_user_token] = user_token['user_token']

    user_token['user_token']
  end

  def fetch_employers(query = '')
    request_params = {
      mapping_status: 'verified,mapped',
      q: query
    }

    provider.fetch_items(request_params)['results']
  end

  def fetch_payroll
    provider.fetch_paystubs(user: @cbv_flow.argyle_user_id)['results']
  end

  def provider
    ArgyleService.new
  end

  def search_params
    params.permit(:query)
  end
end
