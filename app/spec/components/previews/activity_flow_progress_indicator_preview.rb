# frozen_string_literal: true

class ActivityFlowProgressIndicatorPreview < ApplicationPreview
  # @param hours range { min: 0, max: 100, step: 0.5 }
  def one_month(hours: "31.5")
    result = make_result(Date.new(2026, 1, 1), hours.to_f)

    render ActivityFlowProgressIndicator.new(
      monthly_calculation_results: [ result ]
    )
  end

  def one_month_dollars_default
    result = make_result(Date.new(2026, 1, 1), 77, earnings_cents: 597_00)

    render ActivityFlowProgressIndicator.new(
      monthly_calculation_results: [ result ]
    )
  end

  # @param num_months select { choices: [[2 months, 2], [3 months, 3], [4 months, 4]] }
  # @param month_1_hours range { min: 0, max: 100, step: 0.5 }
  # @param month_2_hours range { min: 0, max: 100, step: 0.5 }
  # @param month_3_hours range { min: 0, max: 100, step: 0.5 }
  # @param month_4_hours range { min: 0, max: 100, step: 0.5 }
  def many_months(num_months: "2", month_1_hours: "9.5", month_2_hours: "10.0", month_3_hours: "6.5", month_4_hours: "10.5")
    results = []
    results << make_result(Date.new(2026, 1, 1), month_1_hours)
    results << make_result(Date.new(2025, 12, 1), month_2_hours)
    results << make_result(Date.new(2025, 11, 1), month_3_hours) if num_months.to_i > 2
    results << make_result(Date.new(2025, 10, 1), month_4_hours) if num_months.to_i > 3

    render ActivityFlowProgressIndicator.new(
      monthly_calculation_results: results
    )
  end

  def completed
    results = []
    results << make_result(Date.new(2026, 1, 1), 82)
    results << make_result(Date.new(2025, 12, 1), 91)

    render ActivityFlowProgressIndicator.new(
      monthly_calculation_results: results
    )
  end

  def many_months_mixed_units
    results = []
    results << make_result(Date.new(2026, 1, 1), 77, earnings_cents: 597_00) # dollars
    results << make_result(Date.new(2025, 12, 1), 82, earnings_cents: 620_00) # hours
    results << make_result(Date.new(2025, 11, 1), 40, earnings_cents: 200_00) # hours

    render ActivityFlowProgressIndicator.new(
      monthly_calculation_results: results
    )
  end

  # @param required_months range { min: 1, max: 6, step: 1 }
  def renewal_in_progress(required_months: "3")
    results = []
    results << make_result(Date.new(2026, 1, 1), 0)
    results << make_result(Date.new(2025, 12, 1), 45)
    results << make_result(Date.new(2025, 11, 1), 82)
    results << make_result(Date.new(2025, 10, 1), 50)
    results << make_result(Date.new(2025, 9, 1), 0)
    results << make_result(Date.new(2025, 8, 1), 0)

    render ActivityFlowProgressIndicator.new(
      monthly_calculation_results: results,
      variant: :renewal,
      required_month_count: required_months.to_i
    )
  end

  # @param required_months range { min: 1, max: 6, step: 1 }
  def renewal_completed(required_months: "3")
    results = []
    results << make_result(Date.new(2026, 1, 1), 85)
    results << make_result(Date.new(2025, 12, 1), 90)
    results << make_result(Date.new(2025, 11, 1), 88)
    results << make_result(Date.new(2025, 10, 1), 84)
    results << make_result(Date.new(2025, 9, 1), 35)
    results << make_result(Date.new(2025, 8, 1), 93)

    render ActivityFlowProgressIndicator.new(
      monthly_calculation_results: results,
      variant: :renewal,
      required_month_count: required_months.to_i
    )
  end

  private

  def make_result(month, hours, earnings_cents: 0)
    meets_threshold = hours.to_f >= ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD ||
      earnings_cents >= ActivityFlowProgressCalculator::PER_MONTH_EARNINGS_THRESHOLD

    default_unit = if earnings_cents >= ActivityFlowProgressCalculator::PER_MONTH_EARNINGS_THRESHOLD &&
                      hours.to_f < ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD
                     :dollars
                   else
                     :hours
                   end

    ActivityFlowProgressCalculator::MonthlyResult.new(
      month: month,
      total_hours: hours.to_f,
      total_earnings_cents: earnings_cents,
      default_unit: default_unit,
      meets_requirements: meets_threshold
    )
  end
end
