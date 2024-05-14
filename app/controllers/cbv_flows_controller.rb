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

    raise "ARGYLE_API_TOKEN environment variable is blank. Make sure you have the .env.local.local from 1Password." if Rails.application.credentials.argyle[:api_key].blank?

    res = Net::HTTP.post(URI.parse(USER_TOKEN_ENDPOINT), "", { "Authorization" => "Basic #{Rails.application.credentials.argyle[:api_key]}" })
    parsed = JSON.parse(res.body)
    raise "Argyle API error: #{parsed['detail']}" if res.code.to_i >= 400

    @cbv_flow.update(argyle_user_id: parsed["id"])
    session[:argyle_user_token] = parsed["user_token"]

    parsed["user_token"]
  end

  def fetch_employers(query = "")
    request_params = URI.encode_www_form(
      mapping_status: "verified,mapped",
      q: query
    )
    res = Net::HTTP.get(URI(ITEMS_ENDPOINT).tap { |u| u.query = request_params }, { "Authorization" => "Basic #{Rails.application.credentials.argyle[:api_key]}" })
    parsed = JSON.parse(res)

    parsed["results"]
  end

  def fetch_payroll
    res = Net::HTTP.get(URI.parse("#{PAYSTUBS_ENDPOINT}#{@cbv_flow.argyle_user_id}"), { "Authorization" => "Basic #{Rails.application.credentials.argyle[:api_key]}" })
    parsed = JSON.parse(res)

    parsed["results"]
  end

  def search_params
    params.permit(:query)
  end
end
