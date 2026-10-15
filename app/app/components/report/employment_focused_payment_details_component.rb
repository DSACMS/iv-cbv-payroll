class Report::EmploymentFocusedPaymentDetailsComponent < ViewComponent::Base
  include ReportViewHelper

  def initialize(report, payroll_account, is_w2_worker:)
    @report = report
    @payroll_account = payroll_account
    @account_report = report.find_account_report(payroll_account.aggregator_account_id)
    @is_w2_worker = is_w2_worker
    @monthly_summaries = report.summarize_by_month.fetch(payroll_account.aggregator_account_id, {})
  end

  private

  def compensation
    income = @account_report.income
    return I18n.t("shared.not_applicable") unless @payroll_account.job_succeeded?("income") && income&.compensation_amount

    unit = translate_aggregator_value("payment_frequencies", income.compensation_unit)
    [ format_money(income.compensation_amount), unit ].compact.join(" ")
  end

  def month_rows(month)
    summary = @monthly_summaries[month.strftime("%Y-%m")]
    paystubs = summary&.fetch(:paystubs, []) || []
    hours_available = @is_w2_worker ? paystubs.any? : summary&.fetch(:gigs, [])&.any?
    hours = summary&.fetch(@is_w2_worker ? :total_w2_hours : :total_gig_hours, nil)
    {
      month: I18n.l(month, format: :month_year),
      gross_income: paystubs.any? ? format_money(summary[:accrued_gross_earnings]) : I18n.t("shared.not_applicable"),
      number_of_paychecks: paystubs.count,
      hours_worked: hours_available ? format_hours(hours) : I18n.t("shared.not_applicable")
    }
  end
end
