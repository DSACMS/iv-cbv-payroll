# frozen_string_literal: true

class MemorableDateComponent < ViewComponent::Base
  def initialize(form:, attribute:, legend:, hint: nil)
    @form = form
    @attribute = attribute
    @legend = legend
    @hint = hint
  end

  private

  attr_reader :form, :attribute, :legend, :hint

  def field_name
    form.object_name
  end

  def date_values
    raw_value = form.object.send(attribute)
    return {} unless raw_value.is_a?(Date)

    {
      year: raw_value.year,
      month: raw_value.month,
      day: raw_value.day
    }
  end
end
