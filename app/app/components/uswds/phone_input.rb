# frozen_string_literal: true

class Uswds::PhoneInput < ViewComponent::Base
  def initialize(name:, value: nil, label: nil, id: nil, input_class: "usa-input", **html_options)
    @name = name
    @value = value
    @label = label
    @id = id || name.to_s.parameterize(separator: "_")
    @input_class = input_class
    @html_options = html_options
  end

  private

  def icon_href
    helpers.asset_path("@uswds/uswds/dist/img/sprite.svg#phone")
  end
end
