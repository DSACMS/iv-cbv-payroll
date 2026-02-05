class ActivityFlowNavigator
  include Rails.application.routes.url_helpers

  def initialize(params, overall_progress_result: nil)
    @params = params
    @overall_progress_result = overall_progress_result
  end

  def next_path
    case @params[:controller]
    when "activities/entries"
      activities_flow_root_path
    when "activities/activities"
      activities_flow_summary_path
    when "cbv/employer_searches"
      activities_flow_income_synchronizations_path
    when "cbv/synchronizations"
      activities_flow_income_payment_details_path
    when "cbv/payment_details"
      after_income_path
    when "activities/submit"
      activities_flow_success_path
    end
  end

  def income_sync_path(step, **params)
    case step
    when :employer_search
      activities_flow_income_employer_search_path(**params)
    when :synchronizations
      activities_flow_income_synchronizations_path(**params)
    when :payment_details
      activities_flow_income_payment_details_path(**params)
    when :synchronization_failures
      activities_flow_income_synchronization_failures_path
    end
  end

  private

  def after_income_path
    return activities_flow_root_path unless @overall_progress_result

    @overall_progress_result.meets_requirements ? activities_flow_summary_path : activities_flow_root_path
  end
end
