# frozen_string_literal: true

class ActivityFlowProgressCalculator
  PER_MONTH_HOURS_THRESHOLD = 80

  OverallResult = Struct.new(:total_hours, :meets_requirements, keyword_init: true)
  MonthlyResult = Struct.new(:month, :total_hours, :meets_requirements, keyword_init: true)

  def initialize(activity_flow)
    @activity_flow = activity_flow
    @activities = activity_flow.volunteering_activities + activity_flow.job_training_activities
  end

  def overall_result
    OverallResult.new(
      total_hours: total_hours,
      meets_requirements: each_month_meets_threshold?
    )
  end

  def monthly_results
    reporting_months.map do |month|
      hours = hours_for_month(month)

      MonthlyResult.new(
        month: month,
        total_hours: hours,
        meets_requirements: hours >= PER_MONTH_HOURS_THRESHOLD
      )
    end
  end

  def reporting_months
    @activity_flow.reporting_window_months.times.map do |i|
      @activity_flow.reporting_window_range.begin + i.months
    end
  end

  private

  def total_hours
    @activities.sum { |activity| activity.hours.to_i }
  end

  def each_month_meets_threshold?
    reporting_months.all? do |month_start|
      hours_for_month(month_start) >= PER_MONTH_HOURS_THRESHOLD
    end
  end

  def hours_for_month(month_start)
    @activities
      .select { |activity| activity.date&.between?(month_start, month_start.end_of_month) }
      .sum { |activity| activity.hours.to_i }
  end
end
