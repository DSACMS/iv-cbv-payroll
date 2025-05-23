class Report::MonthlySummaryTableComponent < ViewComponent::Base
  include ReportViewHelper

  def initialize(report, payroll_account)
    @payroll_account = payroll_account
    @report = report
    @employer_name = "test employer name"
  end

  def summarize_by_month(from_date: nil, to_date: nil)
    account_id = @payroll_account.pinwheel_account_id # payroll_account.pinwheel_account_id
    paystubs = @report.paystubs.filter { |paystub| paystub.account_id == account_id }
    gigs = @report.gigs.filter { |gig| gig.account_id == account_id }

    extracted_dates = self.class.extract_dates(paystubs, gigs)
    months = self.class.unique_months(extracted_dates)

    # Group paystubs and gigs by month
    grouped_data = months.each_with_object({}) do |month_string, result|
      month_beginning = self.class.parse_month_safely(month_string).beginning_of_month
      month_end = month_beginning.end_of_month

      paystubs_in_month = paystubs.select { |paystub| self.class.parse_date_safely(paystub.pay_date)&.between?(month_beginning, month_end) }
      gigs_in_month = gigs.select { |gig| self.class.parse_date_safely(gig.end_date)&.between?(month_beginning, month_end) }
      extracted_dates_in_month = self.class.extract_dates(paystubs_in_month, gigs_in_month)

      result[month_string] = {
        paystubs: paystubs_in_month,
        gigs: gigs_in_month,
        accrued_gross_earnings: paystubs_in_month.sum { |paystub| paystub.gross_pay_amount || 0 },
        total_gig_hours: gigs_in_month.sum { |gig| gig.hours },
        partial_month_range: self.class.partial_month_details(month_string, extracted_dates_in_month, from_date, to_date)
      }
    end

    grouped_data
  end

  # Calculate whether the current month is a partial month.
  # When you compute the row month labels, usually the first and last month will need to be
  # labeled a "partial month" per the design. The only exception to this is if the start of the
  # report range is the first of a month and the end is the last of a month.
  # In all other cases we will mark the first and last months as partial.
  def self.partial_month_details(current_month_string, activity_dates, report_from_date, report_to_date)
    start_of_month = self.format_date(self.parse_month_safely(current_month_string).beginning_of_month)
    end_of_month = self.format_date(self.parse_month_safely(current_month_string).end_of_month)

    # Note: activity_dates should always have an item due to how this method is called.
    if activity_dates.empty?
      { is_partial_month: false, included_range_start: start_of_month, included_range_end: end_of_month }
    ## String comparisons of current month to report month range
    elsif current_month_string == self.format_month(report_from_date)
      earliest_activity = self.format_date(activity_dates.min)
      { is_partial_month: earliest_activity != start_of_month, included_range_start: earliest_activity, included_range_end: end_of_month }
    elsif current_month_string == self.format_month(report_to_date)
      latest_activity = self.format_date(activity_dates.max)
      { is_partial_month: latest_activity != end_of_month, included_range_start: start_of_month, included_range_end: latest_activity }
    else
      { is_partial_month: false, included_range_start: start_of_month, included_range_end: end_of_month }
    end
  end

  # date_strings are used in ResponseObjects to store months in the "2010-01-01" format.
  # This is a local static method to parse these into date objects. May return nil on error.
  def self.parse_date_safely(date_string)
    DateTime.parse(date_string) rescue nil
  end

  # month_strings are used in the context of the monthly summaries in the format "2010-01".
  # This method parses these into date objects.  May return nil on error.
  def self.parse_month_safely(month_string)
    Date.strptime(month_string, "%Y-%m") rescue nil
  end

  # formats a date object into a month string "2010-05"
  def self.format_month(date)
    return nil unless date
    date.strftime("%Y-%m")
  end

  def self.format_date(date)
    return nil unless date
    date.strftime("%Y-%m-%d")
  end

  # Given a list of dates, returns a deduplicated list of months in reverse chronological order (newest first).
  def self.unique_months(dates)
    dates.map { |date| self.format_month(date) }
         .compact
         .uniq
         .sort_by { |month_string| self.parse_month_safely(month_string) }
         .reverse
  end

  # return all paystub.pay_date and gig.start_date into a single list of dates.
  # this is used as a helper to determine all unique months present in the report.
  def self.extract_dates(paystubs, gigs)
    (paystubs.map { |paystub| parse_date_safely(paystub.pay_date) } + gigs.map { |gig| parse_date_safely(gig.start_date) }).compact
  end

  def accrued_gross_earnings_cell_value(accrued_gross_earnings)
    format_money(accrued_gross_earnings)
  end

  def total_gig_hours_cell_value(total_gig_hours)
    total_gig_hours
  end

  def month_cell_value(date)
    format_parsed_date(date, :month_year)
  end
end
