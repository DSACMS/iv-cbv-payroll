# frozen_string_literal: true

class TableComponent < ViewComponent::Base
  renders_one :header, TableHeaderComponent
  renders_one :header_two_column, TableHeaderTwoColumnComponent
  renders_one :subheader_row, TableRowComponent
  renders_many :rows, types: {
    content: {
      renders: TableRowComponent,
      as: :row
    },
    section: TableRowSectionHeaderComponent,
    data_point: {
      renders: AggregateDataPointComponent,
      as: :data_point
    }
  }

  def initialize(is_responsive: false, class_names: "", thead_class_names: "border-top-05")
    @class_names = "usa-table usa-table--borderless width-full"
    @class_names = [ @class_names, class_names ].join(" ") if class_names.present?
    @class_names = [ @class_names, " usa-table--stacked" ].join(" ") if is_responsive
    @thead_class_names = thead_class_names
  end

  def before_render
    @row_count = rows.count
  end

  def render?
    @row_count > 0
  end
end
