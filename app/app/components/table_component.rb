# frozen_string_literal: true

class TableComponent < ViewComponent::Base
  include ApplicationHelper

  renders_one :header
  renders_many :rows, types: {
    content: {
      renders: TableRowComponent,
      as: :row
    },
    section: TableRowSectionHeaderComponent,
    data_point: {
      renders: PinwheelDataPointComponent,
      as: :data_point
    }
  }

  def before_render
    @row_count = rows.count
  end

  def render?
    @row_count > 0
  end
end
