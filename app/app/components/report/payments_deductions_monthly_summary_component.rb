# frozen_string_literal: true

class Report::PaymentsDeductionsMonthlySummaryComponent < ViewComponent::Base
  include ReportViewHelper
  include Cbv::MonthlySummaryHelper

  attr_reader :employer_name

  def initialize(report, payroll_account, is_responsive: true, is_w2_worker:, pay_frequency_text:)
    @aggregator_report = report

    # Note: payroll_account may either be the ID or the payroll_account object
    @account_id = payroll_account.class == String ? payroll_account : payroll_account.pinwheel_account_id
    @payroll_account_report = @aggregator_report.find_account_report(@account_id)
    @monthly_summary_data = @aggregator_report.summarize_by_month[@account_id]
    @is_responsive = is_responsive
    @is_w2_worker = is_w2_worker
    @pay_frequency_text = pay_frequency_text
  end

  def before_render
    # Note: since ViewComponents do not know about what view they are rendered in until render time,
    # the translation keys are not available until the before_render method.
    @report_data_range = report_data_range(@aggregator_report, @account_id)
  end

  private

  def has_monthly_summary_results?
    @monthly_summary_data.present?
  end
end
