class Report::MonthlySummaryTableComponent < ViewComponent::Base
  include ReportViewHelper
  include Report::MonthlySummaryTableHelper

  def initialize(report, payroll_account)
    @payroll_account = payroll_account
    @report = report
    @employer_name = employer_name
  end

  def employer_name
    account_id = @payroll_account.pinwheel_account_id
    employment = @report.employments.find { |e| e.account_id == account_id }
    employment.employer_name if employment
  end

  def paystubs
    account_id = @payroll_account.pinwheel_account_id
    @report.paystubs.filter { |paystub| paystub.account_id == account_id }
  end

  def summarize_by_month(from_date: nil, to_date: nil)
    account_id = @payroll_account.pinwheel_account_id
    paystubs = @report.paystubs.filter { |paystub| paystub.account_id == account_id }
    gigs = @report.gigs.filter { |gig| gig.account_id == account_id }
    extracted_dates = extract_dates(paystubs, gigs)
    months = unique_months(extracted_dates)

    from_date = parse_month_safely(months.last) if from_date.nil?
    to_date = parse_month_safely(months.first) if to_date.nil?

    # Group paystubs and gigs by month
    grouped_data = months.each_with_object({}) do |month_string, result|
      month_beginning = parse_month_safely(month_string).beginning_of_month
      month_end = month_beginning.end_of_month

      paystubs_in_month = paystubs.select { |paystub| parse_date_safely(paystub.pay_date)&.between?(month_beginning, month_end) }
      gigs_in_month = gigs.select { |gig| parse_date_safely(gig.end_date)&.between?(month_beginning, month_end) }
      extracted_dates_in_month = extract_dates(paystubs_in_month, gigs_in_month)

      result[month_string] = {
        paystubs: paystubs_in_month,
        gigs: gigs_in_month,
        accrued_gross_earnings: paystubs_in_month.sum { |paystub| paystub.gross_pay_amount || 0 },
        total_gig_hours: gigs_in_month.sum { |gig| gig.hours },
        partial_month_range: partial_month_details(month_string, extracted_dates_in_month, from_date, to_date)
      }
    end

    grouped_data
  end
end
