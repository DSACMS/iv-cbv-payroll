# frozen_string_literal: true

class Uswds::ComboBox < ViewComponent::Base
  def initialize(name:, options:, selected: nil, label: nil, include_blank: true, **html_options)
    @name = name
    @select_options = options
    @selected = selected
    @label = label
    @id = html_options.delete(:id) { name.to_s.parameterize(separator: "_") }
    @include_blank = include_blank
    @select_attrs = { name: @name, id: @id, class: "usa-select" }.merge(html_options)
  end
end
