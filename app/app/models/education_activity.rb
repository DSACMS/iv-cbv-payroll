class EducationActivity < ApplicationRecord
  belongs_to :activity_flow

  # Status is the API request/verification status
  enum :status, {
    unknown: "unknown",
    no_enrollments: "no_enrollments",
    succeeded: "succeeded",
    failed: "failed"
  }, default: :unknown, prefix: :sync

  def display_status
    case status.to_sym
    when :succeeded
      I18n.t("activities.education.enrollment_status.succeeded")
    when :no_enrollments
      I18n.t("activities.education.enrollment_status.no_enrollments")
    else
      I18n.t("activities.education.enrollment_status.unknown")
    end
  end
end
