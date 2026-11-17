class ActivityFlowEmploymentSummary < ApplicationRecord
  include Redactable

  belongs_to :activity_flow
  belongs_to :payroll_account

  validates :activity_flow_id, uniqueness: { scope: :payroll_account_id }

  has_redactable_fields(
    employer_name: :string,
    employment_type: :string,
    employer_phone_number: :string,
    employer_address: :string,
    employment_status: :string,
    employment_start_date: :date,
    employment_termination_date: :date,
    pay_frequency: :string,
    compensation_amount: :integer,
    compensation_unit: :string,
  )

  # Redactable doesn't support integer fields, so compensation_amount (cents)
  # is redacted separately after the string/date fields above are handled.
  def redact!
    super
    update_column(:compensation_amount, nil)
  end

  def self.load_complete_summary_data(activity_flow:)
    payroll_accounts = activity_flow.payroll_accounts.published.select(&:sync_succeeded?)
    return nil if payroll_accounts.empty?

    rows = activity_flow.activity_flow_employment_summaries
      .unredacted
      .where(payroll_account_id: payroll_accounts.map(&:id))
      .includes(:payroll_account)
    return nil unless rows.size == payroll_accounts.size

    rows.index_by { |row| row.payroll_account.aggregator_account_id }.transform_values do |row|
      {
        employer_name: row.employer_name,
        employment_type: row.employment_type,
        employer_phone_number: row.employer_phone_number,
        employer_address: row.employer_address,
        employment_status: row.employment_status,
        employment_start_date: row.employment_start_date,
        employment_termination_date: row.employment_termination_date,
        pay_frequency: row.pay_frequency,
        compensation_amount: row.compensation_amount,
        compensation_unit: row.compensation_unit
      }
    end
  end

  def self.by_account_with_fallback(activity_flow:)
    persisted = load_complete_summary_data(activity_flow: activity_flow)
    return persisted if persisted

    report = AggregatorReportFetcher.new(activity_flow).report
    return {} unless report&.has_fetched?

    activity_flow.payroll_accounts.published.select(&:sync_succeeded?).each do |payroll_account|
      persist_from_report(activity_flow: activity_flow, payroll_account: payroll_account, report: report)
      ActivityFlowMonthlySummary.upsert_from_report(activity_flow: activity_flow, payroll_account: payroll_account, report: report)
    end

    load_complete_summary_data(activity_flow: activity_flow) || {}
  end

  def self.persist_from_report(activity_flow:, payroll_account:, report:)
    return unless report.has_fetched?

    account_report = report.find_account_report(payroll_account.aggregator_account_id)
    employment = account_report&.employment
    income = account_report&.income

    upsert(
      {
        activity_flow_id: activity_flow.id,
        payroll_account_id: payroll_account.id,
        employer_name: employment&.employer_name,
        employment_type: employment&.employment_type&.to_s,
        employer_phone_number: employment&.employer_phone_number,
        employer_address: employment&.employer_address,
        employment_status: employment&.status,
        employment_start_date: employment&.start_date,
        employment_termination_date: employment&.termination_date,
        pay_frequency: income&.pay_frequency,
        compensation_amount: income&.compensation_amount,
        compensation_unit: income&.compensation_unit,
        redacted_at: nil
      },
      unique_by: :index_activity_flow_employment_summaries_on_flow_account,
      update_only: %i[
        employer_name employment_type employer_phone_number employer_address
        employment_status employment_start_date employment_termination_date
        pay_frequency compensation_amount compensation_unit redacted_at
      ]
    )
  end
end
