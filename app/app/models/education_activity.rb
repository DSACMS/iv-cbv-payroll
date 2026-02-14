class EducationActivity < ApplicationRecord
  include DocumentUploadable

  belongs_to :activity_flow
  has_many :nsc_enrollment_terms, dependent: :destroy

  enum :data_source, { self_attested: "self_attested", validated: "validated" }, default: :validated

  # Status is the API request/verification status
  enum :status, {
    unknown: "unknown",
    no_enrollments: "no_enrollments",
    succeeded: "succeeded",
    failed: "failed"
  }, default: :unknown, prefix: :sync

  def progress_hours_for_month(month_start)
    return 0 unless sync_succeeded?

    terms_for_month = nsc_enrollment_terms.select { |term| term.overlaps_month?(month_start) }
    return 0 if terms_for_month.empty?
    return 0 unless terms_for_month.all? { |term| term.half_time_or_above? }

    ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD
  end

  def document_upload_object_title
    # TODO: Do this based off the self-attestation rather than the NSC enrollment term
    nsc_enrollment_terms.first&.school_name&.titleize || "Unknown School"
  end
end
