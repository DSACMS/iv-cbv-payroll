class ActivityFlowProgressIndicator < ViewComponent::Base
  attr_reader :monthly_calculation_results

  def self.from_calculator(progress_calculator)
    new(
      monthly_calculation_results: progress_calculator.monthly_results
    )
  end

  def initialize(monthly_calculation_results:)
    @monthly_calculation_results = monthly_calculation_results
  end

  def percent_complete(monthly_result)
    [
      (100.0 * monthly_result.total_hours) / completion_threshold,
      100
    ].min
  end

  def completion_threshold
    ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD
  end

  def format_hours(hours)
    return hours.to_i if hours.to_i == hours

    hours.round(1)
  end

  def multi_month?
    @monthly_calculation_results.length > 1
  end
end
