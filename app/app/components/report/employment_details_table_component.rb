class Report::EmploymentDetailsTableComponent< ViewComponent::Base
  include ReportViewHelper
  include Cbv::MonthlySummaryHelper

  attr_reader :employer_name

  def initialize(report, payroll_account, is_responsive: true, show_identity: false, show_income: false)
    @show_identity = show_identity
    @show_income = show_income
    @is_responsive = is_responsive

    account_report = find_account_report(report, payroll_account)
    # Note: payroll_account may either be the ID or the payroll_account object
    @employment = account_report&.employment
    @income = account_report&.income
    @identity = account_report&.identity
  end

  private

  def find_account_report(report, payroll_account)
    account_id = payroll_account.class == String ? payroll_account : payroll_account.pinwheel_account_id
    report.find_account_report(account_id)
  end
end
