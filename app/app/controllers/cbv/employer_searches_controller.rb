class Cbv::EmployerSearchesController < Cbv::BaseController
  # Disable CSP since Pinwheel relies on inline styles
  content_security_policy false, only: :show
  after_action :track_accessed_search_event, only: :show
  after_action :track_applicant_searched_event, only: :show

  def show
    @query = search_params[:query]
    @employers = @query.blank? ? [] : fetch_employers(@query)
    @has_pinwheel_account = @cbv_flow.pinwheel_accounts.any?
    @type = search_params[:type]

    case @type
    when "payroll"
      track_clicked_popular_payroll_providers_event if params[:type].present?
    when "employer"
      track_clicked_popular_app_employers_event if params[:type].present?
    end
  end

  private

  def search_params
    params.permit(:query, :type).with_defaults(type: "payroll")
  end

  def fetch_employers(query = "")
    request_params = {
      q: query,
      supported_jobs: [ "paystubs" ]
    }

    pinwheel.fetch_items(request_params)["data"]
  end

  def track_clicked_popular_payroll_providers_event
    NewRelicEventTracker.track("ApplicantClickedPopularPayrollProviders", {
      timestamp: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantClickedPopularPayrollProviders): #{ex}"
  end

  def track_clicked_popular_app_employers_event
    NewRelicEventTracker.track("ApplicantClickedPopularAppEmployers", {
      timestamp: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantClickedPopularAppEmployers): #{ex}"
  end

  def track_accessed_search_event
    return if @query.present?

    NewRelicEventTracker.track("ApplicantAccessedSearchPage", {
      timestamp: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantAccessedSearchPage): #{ex}"
  end

  def track_applicant_searched_event
    return if @query.blank?

    NewRelicEventTracker.track("ApplicantSearchedForEmployer", {
      timestamp: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      num_results: @employers.length,
      has_pinwheel_account: @has_pinwheel_account,
      query: search_params[:query]
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantSearchedForEmployer): #{ex}"
  end
end
