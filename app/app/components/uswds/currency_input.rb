# frozen_string_literal: true

class Uswds::CurrencyInput < ViewComponent::Base
  def initialize(name:, value: nil, id: nil, input_class: "usa-input", **html_options)
    @name = name
    @value = format_value(value)
    @id = id || name.to_s.parameterize(separator: "_")
    @input_class = input_class
    @html_options = html_options
  end

  private

  def format_value(value)
    return value unless value.is_a?(BigDecimal)

    value == value.truncate ? value.to_i : value.to_s("F")
  end

  def icon_href
    helpers.asset_path("@uswds/uswds/dist/img/sprite.svg#attach_money")
  end
end
