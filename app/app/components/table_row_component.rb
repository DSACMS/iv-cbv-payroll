# frozen_string_literal: true

class TableRowComponent < ViewComponent::Base
  renders_many :data_cells, TableCellComponent

  def initialize(*cells, highlight: false, class_names: "")
    @cells = cells
    highlight_class = @highlight ? "cbv-row-highlight" : ""
    @class_names = [ highlight_class, class_names ].join(" ").strip
  end
end
