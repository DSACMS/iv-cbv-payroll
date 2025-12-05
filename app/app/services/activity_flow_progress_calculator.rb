# frozen_string_literal: true

class ActivityFlowProgressCalculator
  Result = Struct.new(:total_hours, keyword_init: true)

  def self.progress(activity_flow)
    volunteering_hours = activity_flow.volunteering_activities.sum(:hours).to_i
    job_training_hours = activity_flow.job_training_activities.sum(:hours).to_i

    Result.new(total_hours: volunteering_hours + job_training_hours)
  end
end
