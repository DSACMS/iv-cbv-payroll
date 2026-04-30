# frozen_string_literal: true

class TableRowComponent < ViewComponent::Base
  renders_many :data_cells, TableCellComponent

  def initialize(highlight: false, class_names: "")
    highlight_class = highlight ? "cbv-row-highlight" : ""
    @class_names = [ highlight_class, class_names ].join(" ").strip
  end
end
