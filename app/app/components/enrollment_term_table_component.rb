class EnrollmentTermTableComponent < ViewComponent::Base
  def initialize(nsc_enrollment_term:)
    @nsc_enrollment_term = nsc_enrollment_term
  end

  def enrollment_current_text(is_enrolled)
    if is_enrolled
      I18n.t("components.enrollment_term_table_component.enrollment_current.yes_enrolled")
    else
      I18n.t("components.enrollment_term_table_component.enrollment_current.no_enrolled")
    end
  end

  def enrollment_status_text(enrollment_status)
    case enrollment_status.to_sym
    when :full_time
      I18n.t("components.enrollment_term_table_component.status.full_time")
    when :three_quarter_time
      I18n.t("components.enrollment_term_table_component.status.three_quarter_time")
    when :half_time
      I18n.t("components.enrollment_term_table_component.status.half_time")
    when :less_than_half_time
      I18n.t("components.enrollment_term_table_component.status.less_than_half_time")
    when :enrolled
      I18n.t("components.enrollment_term_table_component.status.enrolled")
    when :unknown
      I18n.t("shared.not_applicable")
    end
  end
end
