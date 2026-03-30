class NscEnrollmentTerm < ApplicationRecord
  belongs_to :education_activity

  SUMMER_MONTHS = [ 5, 6, 7, 8 ].freeze
  enum :enrollment_status, {
    full_time: "full_time",                     # F
    three_quarter_time: "three_quarter_time",   # Q
    half_time: "half_time",                     # H
    less_than_half_time: "less_than_half_time", # L
    enrolled: "enrolled",                       # Y
    unknown: "unknown"
  }, default: :unknown, prefix: :enrollment

  HALF_TIME_OR_ABOVE_STATUSES = %w[full_time three_quarter_time half_time].freeze
  ENROLLMENT_PRIORITIES = {
    "full_time" => 5,
    "three_quarter_time" => 4,
    "half_time" => 3,
    "less_than_half_time" => 2,
    "enrolled" => 1,
    "unknown" => 0
  }.freeze

  def half_time_or_above?
    HALF_TIME_OR_ABOVE_STATUSES.include?(enrollment_status)
  end

  def less_than_half_time?
    !half_time_or_above?
  end

  def enrollment_status_display
    case enrollment_status.to_sym
    when :full_time
      I18n.t("components.enrollment_term_table_component.status.full_time")
    when :three_quarter_time
      I18n.t("components.enrollment_term_table_component.status.three_quarter_time")
    when :half_time
      I18n.t("components.enrollment_term_table_component.status.half_time")
    when :less_than_half_time
      I18n.t("components.enrollment_term_table_component.status.less_than_half_time")
    when :enrolled
      I18n.t("components.enrollment_term_table_component.status.enrolled")
    else
      I18n.t("shared.not_applicable")
    end
  end

  def enrollment_priority
    ENROLLMENT_PRIORITIES.fetch(enrollment_status.to_s, -1)
  end

  def overlaps_month?(month_start)
    month_end = month_start.end_of_month
    term_begin <= month_end && term_end >= month_start
  end

  def within_reporting_window?(reporting_window_range)
    term_begin <= reporting_window_range.max && term_end >= reporting_window_range.min
  end

  def summer_term?
    term_begin.month.in?(SUMMER_MONTHS)
  end

  def spring_term?
    spring_start = Date.new(term_end.year, 4, 1)
    spring_end = Date.new(term_end.year, 6, 30)

    term_end.between?(spring_start, spring_end)
  end

  def self.summer_month?(month_start)
    month_start.month.in?(SUMMER_MONTHS)
  end

  def term_date_display
    if term_begin.year == term_end.year
      "#{I18n.l(term_begin, format: :abbreviated_month)} - #{I18n.l(term_end, format: :abbreviated_month_year)}"
    else
      "#{I18n.l(term_begin, format: :abbreviated_month_year)} - #{I18n.l(term_end, format: :abbreviated_month_year)}"
    end
  end
end
