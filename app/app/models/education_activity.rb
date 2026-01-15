class EducationActivity < ApplicationRecord
  belongs_to :activity_flow

  # Status is stored as int in db: 0=unknown, 1=not_enrolled, 2=enrolled
  enum :status, [ :unknown, :not_enrolled, :enrolled ], default: :unknown

  def display_status
    case status.to_sym
    when :enrolled
      I18n.t("activities.education.enrollment_status.enrolled")
    when :not_enrolled
      I18n.t("activities.education.enrollment_status.not_enrolled")
    else
      I18n.t("activities.education.enrollment_status.unknown")
    end
  end
end
