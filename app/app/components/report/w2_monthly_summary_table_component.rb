class Report::W2MonthlySummaryTableComponent < ViewComponent::Base
  include ReportViewHelper
  include Cbv::MonthlySummaryHelper

  attr_reader :employer_name

  def initialize(report, payroll_account, is_responsive: true, is_caseworker: false, show_footnote: true, is_pdf: false)
    @report = report
    @show_footnote = show_footnote
    @is_pdf = is_pdf

    # Note: payroll_account may either be the ID or the payroll_account object
    @account_id = payroll_account.class == String ? payroll_account : payroll_account.pinwheel_account_id
    account_report = report.find_account_report(@account_id)
    @paystubs = account_report&.paystubs
    @employer_name = account_report&.dig(:employment, :employer_name)
    @monthly_summary_data = report.summarize_by_month[@account_id]
    @is_responsive = is_responsive
    @is_caseworker = is_caseworker
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

  def payments_from_text
    if @is_caseworker
      I18n.t("components.report.monthly_summary_table.payments_from_text_caseworker", employer_name: @employer_name)
    else
      I18n.t("components.report.monthly_summary_table.payments_from_text", employer_name: @employer_name)
    end
  end

  def table_colspan
    3
  end

  def show_footnote?
    @show_footnote
  end

  def format_accrued_gross_earnings(month_summary)
    return I18n.t("shared.not_applicable") if month_summary[:paystubs].empty?
    format_money(month_summary[:accrued_gross_earnings])
  end

  def format_paychecks_count(month_summary)
    month_summary[:paystubs].count
  end

  def format_hours_worked(month_summary)
    return I18n.t("shared.not_applicable") if month_summary[:paystubs].empty?
    format_hours(month_summary[:total_w2_hours])
  end

  def format_no_payments_found
    I18n.t("cbv.payment_details.show.none_found", report_data_range: @report_data_range)
  end
end
