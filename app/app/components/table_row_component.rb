# frozen_string_literal: true

class TableRowComponent < ViewComponent::Base
  def initialize(label:, value:)
    @label = label
    @value = value
  end
end
