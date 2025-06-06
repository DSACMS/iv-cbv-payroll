class Report::MonthlySummaryTableComponent < ViewComponent::Base
  include ReportViewHelper
  include Cbv::MonthlySummaryHelper

  attr_reader :employer_name

  def initialize(report, payroll_account)
    # Note: payroll_account may either be the ID or the payroll_account object
    @account_id = payroll_account.class == String ? payroll_account : payroll_account.pinwheel_account_id
    account_report = report.find_account_report(@account_id)
    @paystubs = account_report&.paystubs
    @employer_name = account_report&.dig(:employment, :employer_name)
    @monthly_summary_data = report.summarize_by_month[@account_id]
  end
end
