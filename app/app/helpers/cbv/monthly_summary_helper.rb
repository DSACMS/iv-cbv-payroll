module Cbv::MonthlySummaryHelper
  include ReportViewHelper
  # Calculate whether the current month is a partial month.
  # When you compute the row month labels, usually the first and last month will need to be
  # labeled a "partial month" per the design. The only exception to this is if the start of the
  # report range is the first of a month and the end is the last of a month.
  # In all other cases we will mark the first and last months as partial.
  def partial_month_details(current_month_string, activity_dates, report_from_date, report_to_date)
    start_of_month = parse_month_safely(current_month_string).beginning_of_month
    end_of_month = parse_month_safely(current_month_string).end_of_month
    earliest_activity = activity_dates.min&.to_date
    latest_activity = activity_dates.max&.to_date

    is_first_month = current_month_string == self.format_month(report_from_date)
    is_last_month = current_month_string == self.format_month(report_to_date)

    details = { is_partial_month: false, description: nil, included_range_start: start_of_month, included_range_end: end_of_month }
    return details if !is_first_month && !is_last_month
    return details if activity_dates.empty?

    is_partial_start = is_first_month && (earliest_activity != start_of_month)
    is_partial_end = is_last_month && (latest_activity != end_of_month)

    is_partial_month = (is_partial_start && is_first_month) || (is_partial_end && is_last_month)

    included_range_start = is_partial_start ? earliest_activity : start_of_month
    included_range_end = is_partial_end ? latest_activity : end_of_month

    details[:is_partial_month] = is_partial_month
    details[:description] = is_partial_month ? partial_month_description(included_range_start, included_range_end) : nil
    details[:included_range_start] = included_range_start
    details[:included_range_end] = included_range_end
    details
  end

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
end
