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

  def overlaps_month?(month_start)
    month_end = month_start.end_of_month
    term_begin <= month_end && term_end >= month_start
  end
end
