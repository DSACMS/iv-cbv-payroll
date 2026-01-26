module Activities::EducationHelper
  def enrollment_status_text(enrollment_status)
    case enrollment_status.to_sym
    when :full_time
      I18n.t("activities.education.enrollment_status.full_time")
    when :three_quarter_time
      I18n.t("activities.education.enrollment_status.three_quarter_time")
    when :half_time
      I18n.t("activities.education.enrollment_status.half_time")
    when :less_than_half_time
      I18n.t("activities.education.enrollment_status.less_than_half_time")
    when :enrolled
      I18n.t("activities.education.enrollment_status.enrolled")
    when :unknown
      I18n.t("shared.not_applicable")
    end
  end
end
