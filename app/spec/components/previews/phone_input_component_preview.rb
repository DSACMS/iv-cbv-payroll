# frozen_string_literal: true

class PhoneInputComponentPreview < ApplicationPreview
  def default
    render(Uswds::PhoneInput.new(
      name: "phone_number",
      label: "Phone number"
    ))
  end

  def with_value
    render(Uswds::PhoneInput.new(
      name: "phone_number",
      label: "Phone number",
      value: "(415) 344-8009"
    ))
  end
end
