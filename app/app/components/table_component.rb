# frozen_string_literal: true

class TableComponent < ViewComponent::Base
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
end
