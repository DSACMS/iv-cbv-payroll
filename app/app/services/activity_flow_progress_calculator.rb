# frozen_string_literal: true

class ActivityFlowProgressCalculator
  PER_MONTH_HOURS_THRESHOLD = 80
  Result = Struct.new(:total_hours, :meets_requirements, keyword_init: true)

  def self.progress(activity_flow)
    new(activity_flow).result
  end

  def initialize(activity_flow)
    @activity_flow = activity_flow
    @activities = activity_flow.volunteering_activities + activity_flow.job_training_activities
  end

  def result
    Result.new(
      total_hours: total_hours,
      meets_requirements: each_month_meets_threshold?
    )
  end

  private

  def total_hours
    @activities.sum { |activity| activity.hours.to_i }
  end

  def each_month_meets_threshold?
    @activity_flow.reporting_window_months.times.all? do |i|
      month_start = @activity_flow.reporting_window_range.begin + i.months
      hours_for_month(month_start) >= PER_MONTH_HOURS_THRESHOLD
    end
  end

  def hours_for_month(month_start)
    @activities
      .select { |activity| activity.date&.between?(month_start, month_start.end_of_month) }
      .sum { |activity| activity.hours.to_i }
  end
end
