class EducationActivity < ApplicationRecord
  belongs_to :activity_flow

  def display_status
    case self.status
    when "full_time"
      then I18n.t(
        'activities.education.enrollment_status.full_time',
      )
    when "part_time"
      then I18n.t(
        'activities.education.enrollment_status.part_time',
      )
    when "less_than_part_time"
      then I18n.t(
        'activities.education.enrollment_status.hours',
        count: credit_hours
      )
    end
  end
end
