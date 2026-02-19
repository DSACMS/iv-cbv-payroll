class CommunityServiceReviewTableComponent < ViewComponent::Base
  def initialize(volunteering_activity:)
    @activity = volunteering_activity
  end

  def formatted_address
    parts = [ @activity.street_address, @activity.city, @activity.state ].select(&:present?)
    parts.join(", ").presence
  end

  def display_value(value)
    value.presence || I18n.t("shared.not_applicable")
  end
end
