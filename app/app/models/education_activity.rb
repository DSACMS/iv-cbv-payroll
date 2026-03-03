class EducationActivity < ApplicationRecord
  include HasActivityMonths

  belongs_to :activity_flow
  has_many :nsc_enrollment_terms, dependent: :destroy
  has_many :education_activity_months, dependent: :destroy
  has_activity_months :education_activity_months

  enum :data_source, { self_attested: "self_attested", validated: "validated" }, default: :validated

  # Status is the API request/verification status
  enum :status, {
    unknown: "unknown",
    no_enrollments: "no_enrollments",
    succeeded: "succeeded",
    failed: "failed"
  }, default: :unknown, prefix: :sync

  def school_name
    # TODO: Once FFS-3814 migration lands, self_attested activities will have
    # school_name as a column. Remove the fallback then.
    read_attribute(:school_name) || nsc_enrollment_terms.first&.school_name || (self_attested? ? "My School" : nil)
  end

  def progress_hours_for_month(month_start)
    return 0 unless sync_succeeded?

    terms_for_month = nsc_enrollment_terms.select { |term| term.overlaps_month?(month_start) }
    return 0 if terms_for_month.empty?
    return 0 unless terms_for_month.all? { |term| term.half_time_or_above? }

    ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD
  end
end
