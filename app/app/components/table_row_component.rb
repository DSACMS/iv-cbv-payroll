# frozen_string_literal: true

class TableRowComponent < ViewComponent::Base
  def initialize(*cells, highlight: false)
    @cells = cells
    @highlight = highlight
  end
end
