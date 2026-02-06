# frozen_string_literal: true

class ActivityFlowProgressCalculator
  PER_MONTH_HOURS_THRESHOLD = 80
  PER_MONTH_EARNINGS_THRESHOLD = 580_00 # in cents

  OverallResult = Struct.new(:total_hours, :meets_requirements, :meets_routing_requirements, keyword_init: true)
  MonthlyResult = Struct.new(:month, :total_hours, :meets_requirements, keyword_init: true)

  def initialize(activity_flow)
    @activity_flow = activity_flow
    @activities = activity_flow.volunteering_activities + activity_flow.job_training_activities
  end

  def overall_result
    OverallResult.new(
      total_hours: total_hours,
      meets_requirements: each_month_meets_threshold?,
      meets_routing_requirements: each_month_meets_threshold_with_validated_data?
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
    @activities.sum { |activity| activity.hours.to_i } + total_employment_hours
  end

  def each_month_meets_threshold?
    reporting_months.all? do |month_start|
      hours_for_month(month_start) >= PER_MONTH_HOURS_THRESHOLD ||
        earnings_for_month(month_start) >= PER_MONTH_EARNINGS_THRESHOLD
    end
  end

  def each_month_meets_threshold_with_validated_data?
    reporting_months.all? do |month_start|
      validated_hours_for_month(month_start) >= PER_MONTH_HOURS_THRESHOLD ||
        validated_earnings_for_month(month_start) >= PER_MONTH_EARNINGS_THRESHOLD
    end
  end

  def hours_for_month(month_start)
    activity_hours = @activities
      .select { |activity| activity.date&.between?(month_start, month_start.end_of_month) }
      .sum { |activity| activity.hours.to_i }

    employment_hours_for_month(month_start) + activity_hours
  end

  # Employment calculations

  def employment_hours_for_month(month_start)
    return 0 unless payroll_report
    raise "Payroll report not fetched" unless payroll_report.has_fetched?

    month_key = month_start.strftime("%Y-%m")

    monthly_summaries.sum do |_account_id, months|
      month_data = months[month_key]
      next 0 unless month_data

      month_data[:total_w2_hours].to_f + month_data[:total_gig_hours].to_f
    end
  end

  def total_employment_hours
    return 0 unless payroll_report
    raise "Payroll report not fetched" unless payroll_report.has_fetched?

    monthly_summaries.sum do |_account_id, months|
      months.sum do |_month_key, month_data|
        month_data[:total_w2_hours].to_f + month_data[:total_gig_hours].to_f
      end
    end
  end

  def earnings_for_month(month_start)
    return 0 unless payroll_report
    raise "Payroll report not fetched" unless payroll_report.has_fetched?

    month_key = month_start.strftime("%Y-%m")

    monthly_summaries.sum do |_account_id, months|
      month_data = months[month_key]
      next 0 unless month_data

      month_data[:accrued_gross_earnings].to_i
    end
  end

  def validated_hours_for_month(month_start)
    validated_employment_hours_for_month(month_start) +
      validated_education_hours_for_month(month_start) +
      validated_volunteering_and_training_hours_for_month(month_start)
  end

  def validated_earnings_for_month(month_start)
    return 0 unless payroll_report
    raise "Payroll report not fetched" unless payroll_report.has_fetched?

    month_key = month_start.strftime("%Y-%m")

    monthly_summaries.slice(*validated_account_ids).sum do |_account_id, months|
      month_data = months[month_key]
      next 0 unless month_data

      month_data[:accrued_gross_earnings].to_i
    end
  end

  def validated_employment_hours_for_month(month_start)
    return 0 unless payroll_report
    raise "Payroll report not fetched" unless payroll_report.has_fetched?

    month_key = month_start.strftime("%Y-%m")

    monthly_summaries.slice(*validated_account_ids).sum do |_account_id, months|
      month_data = months[month_key]
      next 0 unless month_data

      month_data[:total_w2_hours].to_f + month_data[:total_gig_hours].to_f
    end
  end

  def validated_education_hours_for_month(month_start)
    @education_activities
      .select(&:validated?)
      .sum { |education| education.progress_hours_for_month(month_start) }
  end

  def validated_volunteering_and_training_hours_for_month(month_start)
    @activities
      .select(&:validated?)
      .select { |activity| activity.date&.between?(month_start, month_start.end_of_month) }
      .sum { |activity| activity.hours.to_i }
  end

  def validated_account_ids
    @validated_account_ids ||= @activity_flow.payroll_accounts.select(&:validated?).map(&:aggregator_account_id).compact
  end

  def monthly_summaries
    @monthly_summaries ||= payroll_report.summarize_by_month(
      from_date: @activity_flow.reporting_window_range.begin,
      to_date: @activity_flow.reporting_window_range.end
    )
  end

  def payroll_report
    @payroll_report ||= fetch_payroll_report
  end

  def fetch_payroll_report
    return nil if @activity_flow.payroll_accounts.empty?

    fetcher = AggregatorReportFetcher.new(@activity_flow)
    fetcher.report
  end
end
