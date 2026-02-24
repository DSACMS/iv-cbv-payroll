class EmploymentReviewTableComponent < ViewComponent::Base
  def initialize(employment_activity:)
    @activity = employment_activity
  end

  def display_value(value)
    value.presence || I18n.t("shared.not_applicable")
  end
end
