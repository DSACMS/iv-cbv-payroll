class Cbv::EmployerSearchesController < Cbv::BaseController
  before_action :check_webhooks_initialization_in_development
  after_action :track_accessed_search_event, only: :show
  after_action :track_applicant_searched_event, only: :show

  def show
    @query = search_params[:query]
    @employers = @query.blank? ? [] : provider_search(@query)
    @has_payroll_account = @flow.payroll_accounts.any?
    @selected_tab = search_params[:type] || "payroll"

    # Since this controller is shared between CBV and Activity flows, make sure
    # the links on the page keep the user within the same flow:
    @search_path = flow_navigator.income_sync_path(:employer_search)
    @payroll_path = flow_navigator.income_sync_path(:employer_search, type: :payroll)
    @employer_path = flow_navigator.income_sync_path(:employer_search, type: :employer)

    case search_params[:type]
    when "payroll"
      track_clicked_popular_payroll_providers_event
    when "employer"
      track_clicked_popular_app_employers_event
    end
  end

  private

  def check_webhooks_initialization_in_development
    return unless Rails.env.development?

    if Rails.application.config.webhooks_initialization_error
      flash.now[:alert] = "Unable to initialize Pinwheel or Argyle webhooks: #{Rails.application.config.webhooks_initialization_error}"
    end
  end

  def provider_search(query = "")
    ProviderSearchService.new(@flow.cbv_applicant.client_agency_id).search(query)
  end

  def search_params
    params.slice(:query, :type)
  end

  def track_clicked_popular_payroll_providers_event
    event_logger.track(TrackEvent::ApplicantClickedPopularPayrollProviders, request, {
      time: Time.now.to_i,
      cbv_applicant_id: @flow.cbv_applicant_id,
      cbv_flow_id: @flow.id,
      device_id: @flow.device_id,
      client_agency_id: current_agency&.id,
      invitation_id: @flow.invitation_id
    })
  end

  def track_clicked_popular_app_employers_event
    event_logger.track(TrackEvent::ApplicantClickedPopularAppEmployers, request, {
      time: Time.now.to_i,
      cbv_applicant_id: @flow.cbv_applicant_id,
      cbv_flow_id: @flow.id,
      client_agency_id: current_agency&.id,
      device_id: @flow.device_id,
      invitation_id: @flow.invitation_id
    })
  end

  def track_accessed_search_event
    return if @query.present?

    event_logger.track(TrackEvent::ApplicantAccessedSearchPage, request, {
      time: Time.now.to_i,
      cbv_applicant_id: @flow.cbv_applicant_id,
      cbv_flow_id: @flow.id,
      client_agency_id: current_agency&.id,
      device_id: @flow.device_id,
      invitation_id: @flow.invitation_id
    })
  end

  def track_applicant_searched_event
    return if @query.blank?

    event_logger.track(TrackEvent::ApplicantSearchedForEmployer, request, {
      time: Time.now.to_i,
      cbv_applicant_id: @flow.cbv_applicant_id,
      cbv_flow_id: @flow.id,
      client_agency_id: current_agency&.id,
      device_id: @flow.device_id,
      invitation_id: @flow.invitation_id,
      num_results: @employers.length,
      has_payroll_account: @has_payroll_account,
      pinwheel_result_count: @employers.count { |item| item.provider_name == :pinwheel },
      argyle_result_count: @employers.count { |item| item.provider_name == :argyle },
      query: search_params[:query]
    })
  end
end
