# frozen_string_literal: true

class Uswds::ComboBox < ViewComponent::Base
  def initialize(name:, options:, selected: nil, label: nil, id: nil, select_class: "usa-select", **html_options)
    @name = name
    @select_options = options
    @selected = selected
    @label = label
    @id = id || name.to_s.parameterize(separator: "_")
    @select_class = select_class
    @html_options = html_options
  end
end
