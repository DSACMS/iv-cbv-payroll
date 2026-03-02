# frozen_string_literal: true

class CurrencyInputComponentPreview < ApplicationPreview
  def default
    render(Uswds::CurrencyInput.new(name: "gross_income", id: "gross-income"))
  end

  def with_value
    render(Uswds::CurrencyInput.new(name: "gross_income", id: "gross-income", value: "1337"))
  end
end
