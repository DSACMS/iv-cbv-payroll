class Report::MonthlySummaryTableComponent < ViewComponent::Base
  include ReportViewHelper

  def initialize(report, payroll_account)
    # Note: payroll_account may either be the ID or the payroll_account object
    @account_id = payroll_account.class == String ? payroll_account : payroll_account.pinwheel_account_id
    @report = report
    @employer_name = employer_name
    @monthly_summary_data = @report.summarize_by_month[@account_id]
  end

  def employer_name
    employment = @report.employments.find { |e| e.account_id == @account_id }
    employment.employer_name if employment
  end

  def paystubs
    @report.paystubs.filter { |paystub| paystub.account_id == @account_id }
  end
end
