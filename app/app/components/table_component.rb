# frozen_string_literal: true

class TableComponent < ViewComponent::Base
  renders_one :header, TableHeaderComponent
  renders_many :header_cells, lambda { |**kwargs|
    kwargs[:is_header] = true
    TableCellComponent.new(**kwargs)
  }
  renders_many :rows, types: {
    content: {
      renders: TableRowComponent,
      as: :row
    },
    data_point: {
      renders: AggregateDataPointComponent,
      as: :data_point
    }
  }

  def initialize(multi_column: false, subdued_header: false, class_names: "", attributes: {})
    @class_names = "usa-table usa-table--borderless usa-table--stacked"
    @class_names = [ @class_names, "usa-table--multi-column" ].join(" ") if multi_column
    @class_names = [ @class_names, "usa-table--subdued-header" ].join(" ") if subdued_header
    @class_names = [ @class_names, class_names ].join(" ") if class_names.present?
    @attributes = attributes
  end

  def before_render
    @row_count = rows.count
  end

  def render?
    @row_count > 0
  end
end
