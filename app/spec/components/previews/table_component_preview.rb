# frozen_string_literal: true

class TableComponentPreview < ApplicationPreview
  def default
    render(TableComponent.new(class_names: "cbv-table")) do |table|
      table.with_header_cell(scope: "col") { "Field" }
      table.with_header_cell(scope: "col") { "Value" }

      table.with_row do |row|
        row.with_data_cell(is_header: true) { "Employer" }
        row.with_data_cell { "Patuxent Labs" }
      end

      table.with_row do |row|
        row.with_data_cell(is_header: true) { "Net pay" }
        row.with_data_cell { "$1,950.25" }
      end
    end
  end
end
