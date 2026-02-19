# frozen_string_literal: true

class ActivityFlowProgressIndicatorPreview < ApplicationPreview
  # @param hours range { min: 0, max: 100, step: 0.5 }
  def one_month(hours: "31.5")
    result = make_result(Date.new(2026, 1, 1), hours.to_f)

    render ActivityFlowProgressIndicator.new(
      agency_full_name: "Test Agency",
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
      agency_full_name: "Test Agency",
      monthly_calculation_results: results
    )
  end

  def completed
    results = []
    results << make_result(Date.new(2026, 1, 1), 82)
    results << make_result(Date.new(2025, 12, 1), 91)

    render ActivityFlowProgressIndicator.new(
      agency_full_name: "Test Agency",
      monthly_calculation_results: results
    )
  end

  private

  def make_result(month, hours)
    ActivityFlowProgressCalculator::MonthlyResult.new(
      month: month,
      total_hours: hours.to_f,
      meets_requirements: hours.to_f > ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD
    )
  end
end
