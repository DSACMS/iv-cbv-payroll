class Report::MonthlySummaryTableComponent < ViewComponent::Base
  include ReportViewHelper
  include Cbv::MonthlySummaryHelper

  attr_reader :employer_name

  def initialize(report, payroll_account, is_responsive: true, show_payments: true, show_footnote: true)
    @report = report
    @show_payments = show_payments
    @show_footnote = show_footnote

    # Note: payroll_account may either be the ID or the payroll_account object
    @account_id = payroll_account.class == String ? payroll_account : payroll_account.pinwheel_account_id
    account_report = report.find_account_report(@account_id)
    @paystubs = account_report&.paystubs
    @employer_name = account_report&.dig(:employment, :employer_name)
    @monthly_summary_data = report.summarize_by_month[@account_id]
    @is_responsive = is_responsive
  end

  def before_render
    # Note: since ViewComponents do not know about what view they are rendered in until render time,
    # the translation keys are not available until the before_render method.
    @report_data_range = report_data_range(@report)
  end

  private

  def has_monthly_summary_results?
    @monthly_summary_data.present?
  end

  def has_mileage_data?
    @monthly_summary_data.sum { |month_string, month_summary| month_summary[:total_mileage] } > 0
  end

  def show_payments?
    @show_payments
  end

  def show_footnote?
    @show_footnote
  end

  def table_colspan
    if has_mileage_data?
      4
    else
      3
    end
  end

  def format_accrued_gross_earnings(month_summary)
    return I18n.t("shared.not_applicable") if month_summary[:paystubs].empty?
    format_money(month_summary[:accrued_gross_earnings])
  end

  def format_verified_mileage_expenses(month_summary, month_string)
    return I18n.t("shared.not_applicable") if month_summary[:gigs].empty?
    year = parse_month_safely(month_string).year
    cents_per_mile = self.federal_cents_per_mile(year)

    # Note: we need to round miles to dollars x miles rate displayed
    format_money(month_summary[:total_mileage].to_f.round(0) * cents_per_mile)
  end

  def format_verified_mileage_expense_rate(month_summary, month_string)
    year = parse_month_safely(month_string).year
    cents_per_mile = self.federal_cents_per_mile(year)
    t("components.report.monthly_summary_table.dollars_times_miles",
      dollar_amount: format_money(cents_per_mile), number_of_miles: month_summary[:total_mileage].to_f.round(0))
  end

  def format_total_gig_hours(month_summary)
    return I18n.t("shared.not_applicable") if month_summary[:gigs].empty?
    format_hours(month_summary[:total_gig_hours])
  end

  def format_no_payments_found
    I18n.t("cbv.payment_details.show.none_found", report_data_range: @report_data_range)
  end
end
