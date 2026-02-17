# frozen_string_literal: true

# Presents persisted data through the same interface as an aggregator report for views and components
class PersistedReportAdapter
  attr_reader :flow

  def initialize(flow)
    @flow = flow
    @data = flow.monthly_summaries_by_account_with_fallback
  end

  def find_account_report(account_id)
    account_data = @data[account_id]
    return nil unless account_data

    representative = account_data.values.find { |summary| summary[:employer_name].present? } || account_data.values.first || {}

    AccountReport.new(
      paystubs: [],
      employment: Employment.new(
        employer_name: representative[:employer_name],
        employment_type: (representative[:employment_type] || "w2").to_sym
      )
    )
  end

  def summarize_by_month(from_date: nil, to_date: nil)
    @data.transform_values do |months|
      months
        .select { |_month, summary| summary[:paychecks_count].to_i > 0 }
        .sort_by { |month, _summary| month }.reverse.to_h
        .transform_values { |summary| build_month_summary(summary) }
    end
  end

  private

  def build_month_summary(summary)
    count = summary[:paychecks_count].to_i
    {
      accrued_gross_earnings: summary[:accrued_gross_earnings],
      total_w2_hours: summary[:total_w2_hours],
      total_gig_hours: summary[:total_gig_hours],
      total_mileage: summary[:total_mileage],
      paystubs: Array.new(count),
      gigs: Array.new(count),
      partial_month_range: { is_partial_month: false, description: nil }
    }
  end

  Employment = Struct.new(:employer_name, :employment_type, keyword_init: true)
  AccountReport = Struct.new(:paystubs, :employment, keyword_init: true)
end
