# frozen_string_literal: true

class TableRowComponent < ViewComponent::Base
  def initialize(label:, value:, highlight: false)
    @label = label
    @value = value
    @highlight = highlight
  end
end
