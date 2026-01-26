# frozen_string_literal: true

class ActivityFlowProgressCalculator
  HOURS_THRESHOLD = 80
  Result = Struct.new(:total_hours, :meets_requirements, keyword_init: true)

  def self.progress(activity_flow)
    volunteering_hours = activity_flow.volunteering_activities.sum(:hours).to_i
    job_training_hours = activity_flow.job_training_activities.sum(:hours).to_i
    total_hours = volunteering_hours + job_training_hours
    threshold = HOURS_THRESHOLD * activity_flow.reporting_window_months

    Result.new(
      total_hours: total_hours,
      meets_requirements: total_hours >= threshold
    )
  end
end
