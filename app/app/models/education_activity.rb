class EducationActivity < Activity
  include HasActivityMonths
  include DocumentUploadable

  CREDIT_HOUR_CE_MULTIPLIER = 4

  has_many :nsc_enrollment_terms, dependent: :destroy
  has_many :education_activity_months, dependent: :destroy
  has_activity_months :education_activity_months

  validates :school_name, presence: true, if: :self_attested?

  enum :data_source, {
    self_attested: "self_attested",
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

  def progress_hours_for_month(month_start)
    return self_attested_progress_hours_for_month(month_start) if self_attested?

    validated_progress_hours_for_month(month_start)
  end

  private

  # No date column -- skip the inherited date validation from Activity
  def date_within_reporting_window; end

  def self_attested_progress_hours_for_month(month_start)
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
end
