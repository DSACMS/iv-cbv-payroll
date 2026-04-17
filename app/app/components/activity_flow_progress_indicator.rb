class ActivityFlowProgressIndicator < ViewComponent::Base
  def self.from_calculator(
    progress_calculator,
    variant: :application
  )
    new(
      monthly_calculation_results: progress_calculator.monthly_results,
      variant: variant,
      required_month_count: progress_calculator.required_month_count
    )
  end

  def initialize(
    monthly_calculation_results:,
    variant: :application,
    required_month_count: nil
  )
    @monthly_calculation_results = monthly_calculation_results
    @renewal = variant == :renewal
    @required_month_count = normalize_required_month_count(required_month_count)
  end

  def percent_complete(monthly_result)
    progress_value = progress_value_for(monthly_result)
    threshold_value = completion_threshold_for(monthly_result)

    [
      (100.0 * progress_value) / threshold_value,
      100
    ].min
  end

  def hours_completion_threshold = ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD
  def earnings_completion_threshold = ActivityFlowProgressCalculator::PER_MONTH_EARNINGS_THRESHOLD

  def format_hours(hours)
    return hours.to_i if hours.to_i == hours

    hours.round(1)
  end

  def display_progress_amount(monthly_result)
    if display_dollars?(monthly_result)
      format_dollar_amount(monthly_result.total_earnings_cents)
    else
      format_hours(monthly_result.total_hours)
    end
  end

  def display_completion_threshold(monthly_result)
    if display_dollars?(monthly_result)
      format_dollar_amount(earnings_completion_threshold)
    else
      hours_completion_threshold
    end
  end

  def display_hours_unit?(monthly_result) = !display_dollars?(monthly_result)

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

  def renewal_requires_subset_months? = renewal? && required_month_count < total_month_count

  def reporting_window_start_month = ordered_monthly_calculation_results.first&.month

  def reporting_window_end_month = ordered_monthly_calculation_results.last&.month

  private
  attr_reader :monthly_calculation_results, :required_month_count

  def display_dollars?(monthly_result)
    monthly_result.default_unit == :dollars
  end

  def progress_value_for(monthly_result)
    if display_dollars?(monthly_result)
      monthly_result.total_earnings_cents.to_f
    else
      monthly_result.total_hours.to_f
    end
  end

  def completion_threshold_for(monthly_result)
    if display_dollars?(monthly_result)
      earnings_completion_threshold
    else
      hours_completion_threshold
    end
  end

  def format_dollar_amount(cents)
    helpers.number_to_currency(cents.to_f / 100, precision: 0)
  end

  def normalize_required_month_count(required_month_count)
    requested_count = required_month_count || monthly_calculation_results.length
    [ requested_count.to_i, 1 ].max
  end
end
