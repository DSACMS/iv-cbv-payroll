class EducationActivity < ApplicationRecord
  belongs_to :activity_flow

  enum :status, [ :full_time, :part_time, :quarter_time ], default: :quarter_time

  def display_status
    case
    when self.full_time?
      then I18n.t(
        "activities.education.enrollment_status.full_time",
      )
    when self.part_time?
      then I18n.t(
        "activities.education.enrollment_status.part_time",
      )
    else
      I18n.t(
        "activities.education.enrollment_status.hours",
        count: credit_hours
      )
    end
  end
end
