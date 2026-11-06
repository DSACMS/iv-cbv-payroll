class NscEnrollmentTerm < ApplicationRecord
  include Redactable

  has_redactable_fields(
    first_name: :string,
    middle_name: :string,
    last_name: :string,
    school_name: :string
  )

  belongs_to :education_activity

  attr_accessor :no_hours

  validates :supplemental_enrollment_status,
    inclusion: { in: EducationActivity::SELF_ATTESTED_ENROLLMENT_STATUSES },
    if: -> { enrollment_enrolled? && !no_hours }, on: :supplemental_details
  validates :credit_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true,
    if: :supplemental_credit_hours_applicable?, on: :supplemental_details
  before_validation :clear_inapplicable_supplemental_details, on: :supplemental_details

  SUMMER_MONTHS = [ 5, 6, 7, 8 ].freeze
  enum :enrollment_status, {
    full_time: "full_time",                     # F
    three_quarter_time: "three_quarter_time",   # Q
    half_time: "half_time",                     # H
    less_than_half_time: "less_than_half_time", # L
    enrolled: "enrolled",                       # Y: status not released by school
    leave_of_absence: "leave_of_absence",       # A
    withdrawn: "withdrawn",                     # W, S
    graduated: "graduated",                     # G
    deceased: "deceased",                       # D
    unknown: "unknown"
  }, default: :unknown, prefix: :enrollment

  HALF_TIME_OR_ABOVE_STATUSES = %w[full_time three_quarter_time half_time].freeze
  ENROLLMENT_PRIORITIES = {
    "full_time" => 5,
    "three_quarter_time" => 4,
    "half_time" => 3,
    "less_than_half_time" => 2,
    "enrolled" => 1,
    "leave_of_absence" => 0,
    "withdrawn" => 0,
    "graduated" => 0,
    "deceased" => 0,
    "unknown" => 0
  }.freeze

  def half_time_or_above?
    HALF_TIME_OR_ABOVE_STATUSES.include?(enrollment_status)
  end

  def less_than_half_time?
    !half_time_or_above?
  end

  def supplemental_sufficient_enrollment?
    enrollment_enrolled? && HALF_TIME_OR_ABOVE_STATUSES.include?(supplemental_enrollment_status)
  end

  def supplemental_credit_hours_applicable?
    !enrollment_enrolled? || EducationActivity::SELF_ATTESTED_CREDIT_HOURS_STATUSES.include?(supplemental_enrollment_status)
  end

  def supplemental_enrollment_status_display
    return enrollment_status_display unless enrollment_enrolled?
    return I18n.t("shared.not_applicable") if supplemental_enrollment_status.blank?

    I18n.t("activities.education.add_your_term.edit.enrollment_status_options.#{supplemental_enrollment_status}")
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
    when :leave_of_absence, :withdrawn, :graduated, :deceased
      I18n.t("components.enrollment_term_table_component.status.#{enrollment_status}")
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

  def term_date_display(abbreviated: true)
    month_format = abbreviated ? :abbreviated_month : :month
    month_year_format = abbreviated ? :abbreviated_month_year : :month_year

    if term_begin.year == term_end.year
      "#{I18n.l(term_begin, format: month_format)} - #{I18n.l(term_end, format: month_year_format)}"
    else
      "#{I18n.l(term_begin, format: month_year_format)} - #{I18n.l(term_end, format: month_year_format)}"
    end
  end

  private

  def clear_inapplicable_supplemental_details
    if no_hours
      self.supplemental_enrollment_status = nil
      self.credit_hours = 0
    else
      self.supplemental_enrollment_status = nil unless enrollment_enrolled?
      self.credit_hours = nil unless supplemental_credit_hours_applicable?
    end
  end
end
