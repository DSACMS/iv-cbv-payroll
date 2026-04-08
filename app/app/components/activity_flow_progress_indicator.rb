class ActivityFlowProgressIndicator < ViewComponent::Base
  def self.from_calculator(
    progress_calculator,
    variant: :application,
    required_month_count: nil
  )
    new(
      monthly_calculation_results: progress_calculator.monthly_results,
      variant: variant,
      required_month_count: required_month_count
    )
  end

  def initialize(
    monthly_calculation_results:,
    variant: :application,
    required_month_count: nil
  )
    @monthly_calculation_results = monthly_calculation_results
    @renewal = variant.to_s == "renewal"
    @required_month_count = normalize_required_month_count(required_month_count)
  end

  def percent_complete(monthly_result)
    [
      (100.0 * monthly_result.total_hours) / completion_threshold,
      100
    ].min
  end

  def completion_threshold = ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD

  def format_hours(hours)
    return hours.to_i if hours.to_i == hours

    hours.round(1)
  end

  def multi_month? = monthly_calculation_results.length > 1

  def complete_month_count = monthly_calculation_results.count(&:meets_requirements)

  def total_month_count = monthly_calculation_results.length

  def ordered_monthly_calculation_results = @ordered_monthly_calculation_results ||= monthly_calculation_results.sort_by(&:month)

  def complete?
    if renewal?
      complete_month_count >= required_month_count
    else
      complete_month_count == total_month_count
    end
  end

  def renewal? = @renewal

  def reporting_window_start_month = ordered_monthly_calculation_results.first&.month

  def reporting_window_end_month = ordered_monthly_calculation_results.last&.month

  private
  attr_reader :monthly_calculation_results, :required_month_count

  def normalize_required_month_count(required_month_count)
    requested_count = required_month_count || monthly_calculation_results.length
    [ requested_count.to_i, 1 ].max
  end
end
