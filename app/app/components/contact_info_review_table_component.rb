class ContactInfoReviewTableComponent < ViewComponent::Base
  def initialize(rows:)
    @rows = rows
  end

  def self.formatted_address(activity)
    [ activity.street_address, activity.city, activity.state ].select(&:present?).join(", ").presence
  end

  def display_value(value)
    value.presence || I18n.t("shared.not_applicable")
  end
end
