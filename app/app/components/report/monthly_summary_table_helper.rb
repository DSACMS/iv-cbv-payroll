module Report::MonthlySummaryTableHelper
  # date_strings are used in ResponseObjects to store months in the "2010-01-01" format.
  # This is a local static method to parse these into date objects. May return nil on error.
  def parse_date_safely(date_string)
    DateTime.parse(date_string) rescue nil
  end

  # month_strings are used in the context of the monthly summaries in the format "2010-01".
  # This method parses these into date objects.  May return nil on error.
  def parse_month_safely(month_string)
    Date.strptime(month_string, "%Y-%m") rescue nil
  end

  # formats a date object into a month string "2010-05"
  def format_month(date)
    return nil unless date
    date.strftime("%Y-%m")
  end

  def format_date(date)
    return nil unless date
    date.strftime("%Y-%m-%d")
  end

  def partial_month_description(range_start, range_end)
    I18n.t("components.report.monthly_summary_table.partial_month_text",
           start_date: format_parsed_date(range_start, :day_of_month),
           end_date: format_parsed_date(range_end, :day_of_month))
  end

  # Given a list of dates, returns a deduplicated list of months in reverse chronological order (newest first).
  def unique_months(dates)
    dates.map { |date| format_month(date) }
         .compact
         .uniq
         .sort_by { |month_string| parse_month_safely(month_string) }
         .reverse
  end

  # return all paystub.pay_date and gig.start_date into a single list of dates.
  # this is used as a helper to determine all unique months present in the report.
  def extract_dates(paystubs, gigs)
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
