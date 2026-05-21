# frozen_string_literal: true

# Presents persisted data through the same interface as an aggregator report for views and components
class PersistedReportAdapter
  attr_reader :flow

  def initialize(flow)
    @flow = flow
    @monthly_data = flow.monthly_summaries_by_account_with_fallback
    @employment_data = flow.employment_summaries_by_account_with_fallback
  end

  def find_account_report(account_id)
    source = @employment_data[account_id]
    return nil unless source

    AccountReport.new(
      paystubs: [],
      income: nil,
      identity: nil,
      employment: Employment.new(
        employer_name: source[:employer_name],
        employment_type: (source[:employment_type] || "w2").to_sym,
        employer_phone_number: source[:employer_phone_number],
        employer_address: source[:employer_address],
        status: source[:employment_status],
        start_date: source[:employment_start_date],
        termination_date: source[:employment_termination_date]
      )
    )
  end

  def summarize_by_month(from_date: nil, to_date: nil)
    @monthly_data.transform_values do |months|
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

  Employment = Struct.new(
    :employer_name,
    :employment_type,
    :employer_phone_number,
    :employer_address,
    :status,
    :start_date,
    :termination_date,
    keyword_init: true
  )
  AccountReport = Struct.new(:paystubs, :income, :identity, :employment, keyword_init: true)
end
