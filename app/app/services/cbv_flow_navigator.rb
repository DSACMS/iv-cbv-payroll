class CbvFlowNavigator
  include Rails.application.routes.url_helpers

  def initialize(params)
    @params = params
  end

  def next_path
    case @params[:controller]
    when "cbv/generic_links"
      cbv_flow_entry_path
    when "cbv/entries"
      cbv_flow_employer_search_path
    when "cbv/employer_searches"
      cbv_flow_synchronizations_path
    when "cbv/synchronizations"
      cbv_flow_payment_details_path
    when "cbv/missing_results"
      cbv_flow_other_job_path
    when "cbv/payment_details"
      cbv_flow_add_job_path
    when "cbv/other_jobs"
      cbv_flow_applicant_information_path
    when "cbv/applicant_informations"
      cbv_flow_summary_path
    when "cbv/summaries"
      cbv_flow_submits_path
    when "cbv/submits"
      cbv_flow_success_path
    end
  end

  def income_sync_path(step, **params)
    case step
    when :employer_search
      cbv_flow_employer_search_path(**params)
    when :synchronizations
      cbv_flow_synchronizations_path(**params)
    when :payment_details
      cbv_flow_payment_details_path(**params)
    when :synchronization_failures
      cbv_flow_synchronization_failures_path
    end
  end
end
