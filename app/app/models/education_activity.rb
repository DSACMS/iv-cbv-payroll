class EducationActivity < Activity
  include HasActivityMonths
  include DocumentUploadable

  CREDIT_HOUR_CE_MULTIPLIER = 4

  has_many :nsc_enrollment_terms, dependent: :destroy
  has_many :education_activity_months, dependent: :destroy
  has_activity_months :education_activity_months

  validates :school_name, presence: true, if: :fully_self_attested?

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

    all_months_have_half_time_or_above = reporting_months.all? do |month_start|
      terms_for_month = enrollment_terms.select { |term| term.overlaps_month?(month_start) }

      # Consider an activity "validated" if all months are enrolled at least
      # half-time, after taking into account the summer carryover logic.
      terms_for_month.any?(&:half_time_or_above?) ||
        EducationSummerCarryoverService.applies?(enrollment_terms, month_start)
    end

    all_months_have_half_time_or_above ? :validated : :partially_self_attested
  end

  def formatted_address
    [ street_address, city, state ].compact_blank.join(", ").presence
  end

  def community_engagement_hours(credit_hours)
    credit_hours.to_i * CREDIT_HOUR_CE_MULTIPLIER
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

  def document_upload_months_to_verify
    education_activity_months.map(&:month)
  end

  def document_upload_details_for_month(month)
    activity_month = education_activity_months
      .find { |activity_month| activity_month.month == month }

    I18n.t("shared.credit_hours", count: activity_month.hours) if activity_month
  end

  def document_upload_suggestion_text
    "activities.education.document_upload_suggestion_text_html"
  end

  def document_upload_title_i18n_key
    if partially_self_attested? && document_upload_school_names.length > 1
      "activities.document_uploads.new.title_generic"
    else
      "activities.document_uploads.new.title"
    end
  end

  def document_upload_terms_to_verify
    return [] unless partially_self_attested?

    nsc_enrollment_terms
      .select(&:enrollment_less_than_half_time?)
      .sort_by { |term| [ term.term_begin || Date.new(1900, 1, 1), term.term_end || Date.new(1900, 1, 1), term.school_name.to_s ] }
  end

  def document_upload_term_credit_hours(term)
    # Temporary: monthly hours inputs are not implemented yet, so fallback displays 0.
    return I18n.t("shared.credit_hours", count: 0) unless term.has_attribute?(:credit_hours)

    credit_hours = term[:credit_hours]
    return I18n.t("shared.credit_hours", count: 0) if credit_hours.nil?

    I18n.t("shared.credit_hours", count: credit_hours)
  end

  def document_upload_verification_items
    terms = document_upload_terms_to_verify
    return super if terms.empty?

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

  private

  # No date column -- skip the inherited date validation from Activity
  def date_within_reporting_window; end

  def document_upload_school_names
    document_upload_terms_to_verify.filter_map(&:school_name).uniq
  end

  def progress_calculator
    @progress_calculator ||= EducationActivityProgressCalculator.new(self)
  end
end
