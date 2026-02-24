class ContactInfoReviewTableComponent < ViewComponent::Base
  def initialize(rows:)
    @rows = rows
  end

  def display_value(value)
    value.presence || I18n.t("shared.not_applicable")
  end
end
