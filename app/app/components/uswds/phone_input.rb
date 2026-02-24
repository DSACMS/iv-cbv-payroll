# frozen_string_literal: true

class Uswds::PhoneInput < ViewComponent::Base
  def initialize(name:, value: nil, label: nil, **options)
    @name = name
    @value = value
    @label = label
    @id = options.delete(:id) { name.to_s.parameterize(separator: "_") }
    @input_attrs = { type: "tel", name: @name, value: @value, id: @id, class: options.delete(:class) { "usa-input" } }.merge(options)
  end

  private

  def icon_href
    helpers.asset_path("@uswds/uswds/dist/img/sprite.svg#phone")
  end
end
