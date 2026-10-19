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

  def error_id
    "#{form.field_id(attribute)}_error"
  end

  def legend_id
    "#{form.field_id(attribute)}_legend"
  end

  def description_ids
    ids = []
    ids << error_id if form.has_error?(attribute)
    ids << "#{attribute}_hint" if hint.present?
    ids
  end

  def control_aria
    {
      describedby: description_ids.presence&.join(" "),
      invalid: (form.has_error?(attribute) ? "true" : nil)
    }
  end
end
