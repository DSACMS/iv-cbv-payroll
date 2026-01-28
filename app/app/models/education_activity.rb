class EducationActivity < ApplicationRecord
  belongs_to :activity_flow
  has_many :nsc_enrollment_terms, dependent: :destroy

  # Status is the API request/verification status
  enum :status, {
    unknown: "unknown",
    no_enrollments: "no_enrollments",
    succeeded: "succeeded",
    failed: "failed"
  }, default: :unknown, prefix: :sync
end
