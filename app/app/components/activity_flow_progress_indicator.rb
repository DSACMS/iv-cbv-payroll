class ActivityFlowProgressIndicator < ViewComponent::Base
  attr_reader :reporting_month, :hours

  def self.from_calculator(progress_calculator)
    new(
      reporting_month: progress_calculator.reporting_months.last,
      hours: progress_calculator.result.total_hours
    )
  end

  def initialize(hours:, reporting_month:)
    @reporting_month = reporting_month
    @hours = hours
  end

  def percent_complete
    (100.0 * @hours) / completion_threshold
  end

  def completion_threshold
    ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD
  end

  def format_hours(hours)
    return hours.to_i if hours.to_i == hours

    hours.round(1)
  end
end
