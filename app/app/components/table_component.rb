# frozen_string_literal: true

class TableComponent < ViewComponent::Base
  renders_one :header
  renders_many :rows, types: {
    content: TableRowComponent,
    section: TableRowSectionHeaderComponent,
    data_point: PinwheelDataPointComponent
  }
end
