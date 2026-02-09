module ActivitiesHelper
  def any_activities_added?(flow)
    return false unless flow

    flow.education_activities.exists? ||
      flow.volunteering_activities.exists? ||
      flow.job_training_activities.exists? ||
      flow.payroll_accounts.exists?
  end

  def display_progress_indicator?(progress_calculator)
    progress_calculator.overall_result.total_hours > 0
  end
end
