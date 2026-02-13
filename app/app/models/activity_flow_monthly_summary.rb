# frozen_string_literal: true

class ActivityFlowMonthlySummary < ApplicationRecord
  include Redactable

  belongs_to :activity_flow
  belongs_to :payroll_account

  validates :month, presence: true
  validates :activity_flow_id, uniqueness: { scope: %i[payroll_account_id month] }

  # Loads persisted summaries and reshapes them into the format the progress
  # calculator and views expect (account_id => month => data).
  # Returns nil when data is incomplete so callers know to fall back to the API.
  def self.load_complete_summary_data(activity_flow:)
    synced_accounts = activity_flow.payroll_accounts.select(&:sync_succeeded?)
    return nil if synced_accounts.empty?

    months = activity_flow.reporting_months.map(&:beginning_of_month)
    expected_count = synced_accounts.size * months.size
    rows = activity_flow.activity_flow_monthly_summaries
      .unredacted
      .where(month: months)
      .where(payroll_account_id: synced_accounts.map(&:id))
      .includes(:payroll_account)
    return nil if rows.size != expected_count

    rows
      .group_by { |row| row.payroll_account.aggregator_account_id }
      .transform_values do |account_rows|
        account_rows.index_by { |row| row.month.strftime("%Y-%m") }.transform_values do |row|
          {
            employer_name: row.employer_name,
            total_w2_hours: row.total_w2_hours.to_f,
            total_gig_hours: row.total_gig_hours.to_f,
            accrued_gross_earnings: row.accrued_gross_earnings_cents.to_i,
            total_mileage: row.total_mileage.to_f
          }
        end
      end
  end

  def self.by_account_with_fallback(activity_flow:)
    persisted = load_complete_summary_data(activity_flow: activity_flow)
    return persisted if persisted

    report = AggregatorReportFetcher.new(activity_flow).report
    return {} unless report&.has_fetched?

    activity_flow.payroll_accounts.select(&:sync_succeeded?).each do |payroll_account|
      upsert_from_report(activity_flow: activity_flow, payroll_account: payroll_account, report: report)
    end

    load_complete_summary_data(activity_flow: activity_flow) || {}
  end

  def self.upsert_from_report(activity_flow:, payroll_account:, report:)
    return unless report.has_fetched?

    range = activity_flow.reporting_window_range
    account_id = payroll_account.aggregator_account_id
    months_data = report.summarize_by_month(from_date: range.begin, to_date: range.end)[account_id] || {}
    employer_name = report.find_account_report(account_id)&.employment&.employer_name if report.respond_to?(:find_account_report)
    reporting_months = activity_flow.reporting_months

    reporting_months.each do |month_date|
      month_string = month_date.strftime("%Y-%m")
      data = months_data[month_string] || {}

      upsert(
        {
          activity_flow_id: activity_flow.id,
          payroll_account_id: payroll_account.id,
          month: month_date.beginning_of_month,
          total_w2_hours: data[:total_w2_hours].to_f,
          total_gig_hours: data[:total_gig_hours].to_f,
          accrued_gross_earnings_cents: (data[:accrued_gross_earnings] || 0).to_i,
          total_mileage: (data[:total_mileage] || 0).to_f,
          employer_name: employer_name
        },
        unique_by: %i[activity_flow_id payroll_account_id month],
        update_only: %i[
          total_w2_hours total_gig_hours accrued_gross_earnings_cents
          total_mileage employer_name
        ]
      )
    end
  end

  # Redact all persisted income details for this monthly summary row.
  def redact!
    assign_attributes(
      employer_name: Redactable::REDACTION_REPLACEMENTS[:string],
      total_w2_hours: 0,
      total_gig_hours: 0,
      accrued_gross_earnings_cents: 0,
      total_mileage: 0,
      redacted_at: Time.current
    )
    save(validate: false)
  end
end
