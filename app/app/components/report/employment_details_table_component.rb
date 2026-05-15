class Report::EmploymentDetailsTableComponent < ViewComponent::Base
  include ReportViewHelper
  include Cbv::MonthlySummaryHelper

  attr_reader :employer_name

  def initialize(report, payroll_account, show_identity: false, show_income: false, show_header: true, show_employer_name: false, container_class: "margin-top-5")
    @show_identity = show_identity
    @show_income = show_income
    @show_header = show_header
    @show_employer_name = show_employer_name
    @payroll_account = payroll_account
    @container_class = container_class

    account_report = find_account_report(report)
    @employment = account_report&.employment
    @income = account_report&.income
    @identity = account_report&.identity
  end

  private

  def has_income_data?
    @payroll_account.job_succeeded?("income")
  end

  def find_account_report(report)
    # Note: payroll_account may either be the ID or the payroll_account object
    account_id = @payroll_account.class == String ? @payroll_account : @payroll_account.aggregator_account_id
    report.find_account_report(account_id)
  end
end
