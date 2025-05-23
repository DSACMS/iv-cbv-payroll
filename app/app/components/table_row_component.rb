# frozen_string_literal: true

class TableRowComponent < ViewComponent::Base
  renders_many :data_cells
  def initialize(*cells, highlight: false)
    @cells = cells
    @highlight = highlight
  end
end
