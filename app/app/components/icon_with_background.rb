# frozen_string_literal: true

class IconWithBackground < ViewComponent::Base
  def initialize(icon: nil)
    @icon = icon
  end

  private

  attr_reader :icon

  def icon_svg
    return unless icon
    icon_sprite_path = helpers.asset_path("@uswds/uswds/dist/img/sprite.svg")
    icon_path = "#{icon_sprite_path}##{icon}"
    content_tag(:svg, class: "usa-icon", "aria-hidden": true, focusable: false, role: "img") do
      tag.use("", href: icon_path)
    end
  end
end
