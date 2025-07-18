# frozen_string_literal: true

class Report::PaymentsDeductionsMonthlySummaryComponent < ViewComponent::Base
  include ReportViewHelper
  include Cbv::MonthlySummaryHelper

  attr_reader :employer_name

  def initialize(report, payroll_account, is_responsive: true, is_pdf: false)
    @report = report
    @is_pdf = is_pdf

    # Note: payroll_account may either be the ID or the payroll_account object
    @account_id = payroll_account.class == String ? payroll_account : payroll_account.pinwheel_account_id
    @monthly_summary_data = report.summarize_by_month[@account_id]
    @is_responsive = is_responsive
  end

  def before_render
    # Note: since ViewComponents do not know about what view they are rendered in until render time,
    # the translation keys are not available until the before_render method.
    @report_data_range = report_data_range(@report, @account_id)
  end

  private

  def has_monthly_summary_results?
    @monthly_summary_data.present?
  end

  def format_month_string(month_string, summary)
    formatted_month = Date.strptime(month_string, "%Y-%m").strftime("%B %Y")
    if summary[:partial_month_range][:is_partial_month]
      formatted_month = "#{formatted_month} #{summary[:partial_month_range][:description]}"
    end
    formatted_month
  end
end
