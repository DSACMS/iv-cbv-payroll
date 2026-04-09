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

  def initialize(class_names: "", thead_class_names: "", attributes: {})
    @class_names = "usa-table usa-table--borderless width-full activity-review-table usa-table--stacked"
    @class_names = [ @class_names, class_names ].join(" ") if class_names.present?
    @thead_class_names = thead_class_names
    @attributes = attributes
  end

  def before_render
    @row_count = rows.count
  end

  def render?
    @row_count > 0
  end
end
