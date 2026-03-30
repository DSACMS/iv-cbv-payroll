# frozen_string_literal: true

class TableComponentPreview < ApplicationPreview
  def default
    render(TableComponent.new(is_responsive: true, class_names: "cbv-table", thead_class_names: "")) do |table|
      table.with_header_cell(is_header: true, scope: "col") { "Field" }
      table.with_header_cell(is_header: true, scope: "col") { "Value" }

      table.with_row do |row|
        row.with_data_cell(is_header: true, data_label: "Field") { "Employer" }
        row.with_data_cell(data_label: "Value") { "Patuxent Labs" }
      end

      table.with_row do |row|
        row.with_data_cell(is_header: true, data_label: "Field") { "Net pay" }
        row.with_data_cell(data_label: "Value") { "$1,950.25" }
      end
    end
  end
end
