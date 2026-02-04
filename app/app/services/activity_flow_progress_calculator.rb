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
    @education_activities = activity_flow.education_activities
  end

  def result
    Result.new(
      total_hours: total_hours,
      meets_requirements: each_month_meets_threshold?
    )
  end

  def reporting_months
    @activity_flow.reporting_window_months.times.map do |i|
      @activity_flow.reporting_window_range.begin + i.months
    end
  end

  private

  def total_hours
    volunteering_and_training_hours + education_hours
  end

  def volunteering_and_training_hours
    @activities.sum { |activity| activity.hours.to_i }
  end

  def education_hours
    reporting_months.sum { |month_start| education_hours_for_month(month_start) }
  end

  def each_month_meets_threshold?
    reporting_months.all? do |month_start|
      hours_for_month(month_start) >= PER_MONTH_HOURS_THRESHOLD
    end
  end

  def hours_for_month(month_start)
    volunteering_and_training_hours_for_month(month_start) + education_hours_for_month(month_start)
  end

  def volunteering_and_training_hours_for_month(month_start)
    @activities
      .select { |activity| activity.date&.between?(month_start, month_start.end_of_month) }
      .sum { |activity| activity.hours.to_i }
  end

  def education_hours_for_month(month_start)
    @education_activities.sum { |education| education.progress_hours_for_month(month_start) }
  end
end
