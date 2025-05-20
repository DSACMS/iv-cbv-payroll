class Report::MonthlySummaryTableComponent < ViewComponent::Base
  def initialize(report, payroll_account)
    @payroll_account = payroll_account
    @report = report
  end

  def summarize_by_month(from_date: nil, to_date: nil)
    account_id = @payroll_account.pinwheel_account_id # payroll_account.pinwheel_account_id
    paystubs = @report.paystubs.filter { |paystub| paystub.account_id == account_id }
    gigs = @report.gigs.filter { |gig| gig.account_id == account_id }
    employment = @report.employments.filter { |employment| employment.account_id == account_id }.first

    extracted_dates = self.class.extract_dates(paystubs, gigs)
    months = self.class.unique_months(extracted_dates)

    # Group paystubs and gigs by month
    grouped_data = months.each_with_object({}) do |month_string, result|
      month_beginning = self.class.parse_month_safely(month_string).beginning_of_month
      month_end = month_beginning.end_of_month

      paystubs_in_month = paystubs.select { |paystub| self.class.parse_date_safely(paystub.pay_date)&.between?(month_beginning, month_end) }
      gigs_in_month = gigs.select { |gig| self.class.parse_date_safely(gig.end_date)&.between?(month_beginning, month_end) }

      result[month_string] = {
        paystubs: paystubs_in_month,
        gigs: gigs_in_month,
        accrued_gross_earnings: paystubs_in_month.reduce(0) { |sum, paystub| sum + (paystub.gross_pay_amount || 0) },
        total_gig_hours: gigs_in_month.sum { |gig| gig.hours }
      }
    end

    grouped_data
  end


  # def self.partial_month_range(month_string, activity_dates, report_from_date, report_to_date)
  #  month_beginning = self.parse_month_safely(month_string).beginning_of_month
  #  month_end = month_beginning.end_of_month

  #  earliest_activity_date = activity_dates.max
  #  latest_activity_date = activity_dates.min

  #  if month_beginning >= report_from_date && month_end <= report_to_date do

  #  if month_beginning >= earliest_activity_date && month_end <= latest_activity_date do
  #    return { is_partial_month: false }
  #  end
  # end

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

  # Given a list of dates, returns a deduplicated list of months in reverse chronological order (newest first).
  def self.unique_months(dates)
    dates.map { |date| date.strftime("%Y-%m") }.uniq.sort_by { |month_string| self.parse_month_safely(month_string) }.reverse
  end

  # return all paystub.pay_date and gig.start_date into a single list of dates.
  # this is used as a helper to determine all unique months present in the report.
  def self.extract_dates(paystubs, gigs)
    (paystubs.map { |paystub| parse_date_safely(paystub.pay_date) } + gigs.map { |gig| parse_date_safely(gig.start_date) }).compact
  end
end
