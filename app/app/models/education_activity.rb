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

  def self.data_source_from_nsc_results(enrollment_terms)
    enrollment_terms.any?(&:half_time_or_above?) ? :validated : :partially_self_attested
  end

  def formatted_address
    [ street_address, city, state ].compact_blank.join(", ").presence
  end

  def community_engagement_hours(credit_hours)
    credit_hours.to_i * CREDIT_HOUR_CE_MULTIPLIER
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

  def document_upload_terms_for_partial_upload
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
    terms = document_upload_terms_for_partial_upload
    return super if terms.empty?

    terms.map do |term|
      {
        label: "#{term.school_name} #{I18n.l(term.term_begin, format: :short)} to #{I18n.l(term.term_end, format: :short)}:",
        details: document_upload_term_credit_hours(term)
      }
    end
  end

  def progress_hours_for_month(month_start)
    return fully_self_attested_progress_hours_for_month(month_start) if fully_self_attested?

    validated_progress_hours_for_month(month_start)
  end

  private

  # No date column -- skip the inherited date validation from Activity
  def date_within_reporting_window; end

  def fully_self_attested_progress_hours_for_month(month_start)
    month = month_start.beginning_of_month
    monthly_credit_hours = education_activity_months.find_by(month: month)&.hours

    community_engagement_hours(monthly_credit_hours)
  end

  def validated_progress_hours_for_month(month_start)
    return 0 unless sync_succeeded?

    terms_for_month = nsc_enrollment_terms.select { |term| term.overlaps_month?(month_start) }
    return 0 if terms_for_month.empty?
    return 0 unless terms_for_month.all? { |term| term.half_time_or_above? }

    ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD
  end

  def document_upload_school_names
    document_upload_terms_for_partial_upload.filter_map(&:school_name).uniq
  end
end
