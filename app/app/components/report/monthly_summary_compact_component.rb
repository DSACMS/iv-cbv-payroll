class Report::MonthlySummaryCompactComponent < ViewComponent::Base
  include ReportViewHelper
  include Cbv::MonthlySummaryHelper

  attr_reader :employer_name

  def initialize(report, payroll_account)
    # Note: payroll_account may either be the ID or the payroll_account object
    @account_id = payroll_account.class == String ? payroll_account : payroll_account.pinwheel_account_id
    account_report = report.find_account_report(@account_id)
    @paystubs = Array(account_report&.paystubs)
    @total_gross_earnings = @paystubs.sum { |paystub| paystub.gross_pay_amount || 0 }
    @employer_name = account_report&.dig(:employment, :employer_name)
    @monthly_summary_data = report.summarize_by_month[@account_id]
  end

  def total_income_header
    t("components.report.monthly_summary_table.compact.total_income_header",
      employer_name: @employer_name,
      accrued_gross_earnings: format_money(@total_gross_earnings))
  end

  def month_income(month_string, month_summary)
    t("components.report.monthly_summary_table.compact.month_income",
      month: format_date(parse_month_safely(month_string), :month_year),
      accrued_gross_earnings: format_money(month_summary[:accrued_gross_earnings]))
  end
end
