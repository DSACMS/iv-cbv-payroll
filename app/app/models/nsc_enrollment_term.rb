class NscEnrollmentTerm < ApplicationRecord
  belongs_to :education_activity

  enum :enrollment_status, {
    full_time: "full_time",                     # F
    three_quarter_time: "three_quarter_time",   # Q
    half_time: "half_time",                     # H
    less_than_half_time: "less_than_half_time", # L
    enrolled: "enrolled",                       # Y
    unknown: "unknown"
  }, default: :unknown, prefix: :enrollment

  HALF_TIME_OR_ABOVE_STATUSES = %w[full_time three_quarter_time half_time].freeze

  def half_time_or_above?
    HALF_TIME_OR_ABOVE_STATUSES.include?(enrollment_status)
  end

  def less_than_half_time?
    !half_time_or_above?
  end

  def overlaps_month?(month_start)
    month_end = month_start.end_of_month
    term_begin <= month_end && term_end >= month_start
  end

  def within_reporting_window?(reporting_window_range)
    term_begin <= reporting_window_range.max && term_end >= reporting_window_range.min
  end

  def term_date_display
    if term_begin.year == term_end.year
      "#{I18n.l(term_begin, format: :abbreviated_month)} - #{I18n.l(term_end, format: :abbreviated_month_year)}"
    else
      "#{I18n.l(term_begin, format: :abbreviated_month_year)} - #{I18n.l(term_end, format: :abbreviated_month_year)}"
    end
  end
end
