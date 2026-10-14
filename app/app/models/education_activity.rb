class EducationActivity < Activity
  include DocumentUploadable

  CREDIT_HOUR_CE_MULTIPLIER = 13
  SELF_ATTESTED_ENROLLMENT_STATUSES = %w[full_time half_time less_than_half_time unknown].freeze
  SELF_ATTESTED_CREDIT_HOURS_STATUSES = %w[less_than_half_time unknown].freeze
  FIELDS = %w[
    school_name
    street_address
    street_address_line_2
    city
    state
    zip_code
    contact_name
    contact_title
    contact_email
    contact_phone_number
  ].freeze
  PRE_POPULATED_REQUIRED_FIELDS = %w[school_name].freeze

  has_many :nsc_enrollment_terms, dependent: :destroy

  def self.activity_type
    :education
  end

  def self.pre_populated_defaults
    { "data_source" => "fully_self_attested" }
  end

  validates :school_name, presence: true, if: :fully_self_attested?
  validates :self_attested_enrollment_status, inclusion: { in: SELF_ATTESTED_ENROLLMENT_STATUSES }, on: :add_your_term
  validates :self_attested_term_start, :self_attested_term_end, presence: true, on: :add_your_term
  validates :credit_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true,
    if: :self_attested_credit_hours_applicable?, on: :add_your_term
  validate :self_attested_term_dates_in_order, on: :add_your_term
  before_validation :clear_inapplicable_self_attested_credit_hours, on: :add_your_term

  enum :data_source, {
    fully_self_attested: "fully_self_attested",
    partially_self_attested: "partially_self_attested",
    validated: "validated"
  }, default: :validated

  # Status is the API request/verification status
  enum :status, {
    unknown: "unknown",
    no_enrollments: "no_enrollments",
    succeeded: "succeeded",
    failed: "failed"
  }, default: :unknown, prefix: :sync

  def self.data_source_from_nsc_results(enrollment_terms, reporting_months:)
    return :partially_self_attested if enrollment_terms.blank?

    resolver = EducationReportingMonthResolver.new(terms: enrollment_terms, reporting_months: reporting_months)
    all_months_have_sufficient_enrollment = resolver.reporting_month_enrollments.all?(&:sufficient_enrollment?)

    all_months_have_sufficient_enrollment ? :validated : :partially_self_attested
  end

  def formatted_address
    locality = [ city, state ].compact_blank.join(", ")
    locality_zip = [ locality, zip_code ].compact_blank.join(" ")
    [ street_address, street_address_line_2, locality_zip ].compact_blank.join(", ").presence
  end

  def community_engagement_hours(credit_hours)
    (credit_hours || 0) * CREDIT_HOUR_CE_MULTIPLIER
  end

  def self_attested_term?
    fully_self_attested? && self_attested_term_start.present? && self_attested_term_end.present? && self_attested_enrollment_status.present?
  end

  def self_attested_credit_hours_applicable?
    SELF_ATTESTED_CREDIT_HOURS_STATUSES.include?(self_attested_enrollment_status)
  end

  def self_attested_sufficient_enrollment?
    NscEnrollmentTerm::HALF_TIME_OR_ABOVE_STATUSES.include?(self_attested_enrollment_status)
  end

  def self_attested_enrollment_status_display
    I18n.t("activities.education.add_your_term.edit.enrollment_status_options.#{self_attested_enrollment_status}")
  end

  def self_attested_term_overlaps_month?(month_start)
    self_attested_term? && self_attested_term_start <= month_start.end_of_month && self_attested_term_end >= month_start.beginning_of_month
  end

  def self_attested_reporting_months
    activity_flow.reporting_months.select { |month| self_attested_term_overlaps_month?(month) }
  end

  def self_attested_term_date_display
    return if self_attested_term_start.blank? || self_attested_term_end.blank?

    start_format = self_attested_term_start.year == self_attested_term_end.year ? :abbreviated_month : :abbreviated_month_year
    "#{I18n.l(self_attested_term_start, format: start_format)} - #{I18n.l(self_attested_term_end, format: :abbreviated_month_year)}"
  end

  def less_than_half_time_terms_in_reporting_window
    reporting_range = activity_flow.reporting_window_range
    nsc_enrollment_terms
      .select { |term| term.less_than_half_time? && term.within_reporting_window?(reporting_range) }
      .sort_by { |term| [ term.term_begin, term.id ] }
  end

  def has_less_than_half_time_terms?
    less_than_half_time_terms_in_reporting_window.any?
  end

  def review_header_school_name
    school_name.presence || nsc_enrollment_terms.first&.school_name
  end

  def review_description_school_names
    return review_header_school_name unless partially_self_attested?

    school_names = nsc_enrollment_terms.filter_map(&:school_name).uniq.sort
    school_names = [ I18n.t("shared.not_applicable") ] if school_names.empty?
    school_names.to_sentence
  end

  def review_term_credit_hours(term)
    term.attributes["credit_hours"].to_i
  end

  def document_upload_object_title
    if partially_self_attested?
      school_names = document_upload_school_names
      return school_names.first if school_names.one?

      return nil
    end

    school_name
  end

  def document_upload_suggestion_text
    "activities.education.document_upload_suggestion_text_html"
  end

  def document_upload_suggestion_title_i18n_key
    "activities.document_uploads.new.education.suggestion_title"
  end

  def document_upload_title_i18n_key
    if partially_self_attested? && document_upload_school_names.length > 1
      "activities.document_uploads.new.title_generic"
    else
      "activities.document_uploads.new.title"
    end
  end

  def document_upload_header_title_i18n_key
    "activities.education.title_singular"
  end

  def document_upload_terms_to_verify
    return [] unless partially_self_attested?

    nsc_enrollment_terms
      .select(&:enrollment_less_than_half_time?)
      .sort_by { |term| [ term.term_begin || Date.new(1900, 1, 1), term.term_end || Date.new(1900, 1, 1), term.school_name.to_s ] }
  end

  def document_upload_term_credit_hours(term)
    return I18n.t("shared.credit_hours", count: 0) unless term.has_attribute?(:credit_hours)

    credit_hours = term[:credit_hours]
    return I18n.t("shared.credit_hours", count: 0) if credit_hours.nil?

    I18n.t("shared.credit_hours", count: credit_hours)
  end

  def document_upload_verification_items
    terms = document_upload_terms_to_verify
    terms.map do |term|
      {
        label: "#{term.school_name} #{I18n.l(term.term_begin, format: :short)} to #{I18n.l(term.term_end, format: :short)}:",
        details: document_upload_term_credit_hours(term)
      }
    end
  end

  def progress_hours_for_month(month_start)
    progress_calculator.progress_hours_for_month(month_start)
  end

  def routing_hours_for_month(month_start)
    progress_calculator.routing_hours_for_month(month_start)
  end

  def sufficient_enrollment_for_month?(month_start)
    progress_calculator.sufficient_enrollment_for_month?(month_start)
  end

  private

  def clear_inapplicable_self_attested_credit_hours
    self.credit_hours = nil unless self_attested_credit_hours_applicable?
  end

  def self_attested_term_dates_in_order
    return if self_attested_term_start.blank? || self_attested_term_end.blank?
    return if self_attested_term_start < self_attested_term_end

    errors.add(:self_attested_term_end, :invalid)
  end

  # No date column -- skip the inherited date validation from Activity
  def date_within_reporting_window; end

  def document_upload_school_names
    document_upload_terms_to_verify.filter_map(&:school_name).uniq
  end

  def progress_calculator
    @progress_calculator ||= EducationActivityProgressCalculator.new(self)
  end
end
