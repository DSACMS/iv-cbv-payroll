class EducationActivity < ApplicationRecord
  belongs_to :activity_flow

  # Enums values: 0=not_enrolled, 1=quarter_time, 2=half_time, 3=full_time
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
