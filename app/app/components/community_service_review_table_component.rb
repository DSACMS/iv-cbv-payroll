class CommunityServiceReviewTableComponent < ViewComponent::Base
  def initialize(volunteering_activity:)
    @activity = volunteering_activity
  end

  def formatted_address
    parts = [ @activity.street_address, @activity.city, @activity.state ].select(&:present?)
    parts.join(", ") if parts.any?
  end

  def phone_display
    @activity.coordinator_phone_number.presence || I18n.t("shared.not_applicable")
  end
end
