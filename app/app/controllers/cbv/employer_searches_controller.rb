class Cbv::EmployerSearchesController < Cbv::BaseController
  # Disable CSP since Pinwheel relies on inline styles
  content_security_policy false, only: :show
  before_action :check_pinwheel_initialization
  after_action :track_accessed_search_event, only: :show
  after_action :track_applicant_searched_event, only: :show

  def show
    @query = search_params[:query]
    @employers = @query.blank? ? [] : provider_search(@query)
    @has_payroll_account = @cbv_flow.payroll_accounts.any?
    @selected_tab = search_params[:type] || "payroll"
    @pinwheel_search_result_count = 0
    @argyle_search_result_count = 0

    case search_params[:type]
    when "payroll"
      track_clicked_popular_payroll_providers_event
    when "employer"
      track_clicked_popular_app_employers_event
    end
  end

  private

  def check_pinwheel_initialization
    return unless Rails.env.development?

    if Rails.application.config.pinwheel_initialization_error
      flash.now[:alert] = "Unable to initialize Pinwheel: #{Rails.application.config.pinwheel_initialization_error}"
    end
  end

  def provider_search(query = "")
    search_results = ProviderSearchService.new(@cbv_flow.client_agency_id).search(query)
    @pinwheel_search_result_count = search_results.count { |item| item.provider_name == :pinwheel }
    @argyle_search_result_count = search_results.count { |item| item.provider_name == :argyle }
    search_results
  end

  def search_params
    params.slice(:query, :type)
  end

  def track_clicked_popular_payroll_providers_event
    event_logger.track("ApplicantClickedPopularPayrollProviders", request, {
      timestamp: Time.now.to_i,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantClickedPopularPayrollProviders): #{ex}"
  end

  def track_clicked_popular_app_employers_event
    event_logger.track("ApplicantClickedPopularAppEmployers", request, {
      timestamp: Time.now.to_i,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantClickedPopularAppEmployers): #{ex}"
  end

  def track_accessed_search_event
    return if @query.present?

    event_logger.track("ApplicantAccessedSearchPage", request, {
      timestamp: Time.now.to_i,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantAccessedSearchPage): #{ex}"
  end

  def track_applicant_searched_event
    return if @query.blank?

    event_logger.track("ApplicantSearchedForEmployer", request, {
      timestamp: Time.now.to_i,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      num_results: @employers.length,
      has_payroll_account: @has_payroll_account,
      pinwheel_result_count: @@pinwheel_search_result_count,
      argyle_result_count: @argyle_search_result_count,
      query: search_params[:query]
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantSearchedForEmployer): #{ex}"
  end
end
