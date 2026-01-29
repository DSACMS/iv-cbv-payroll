# frozen_string_literal: true

class TableComponentPreview < ApplicationPreview
  def with_sections_and_responsive_rows
    render(TableComponent.new(is_responsive: true, thead_class_names: "")) do |table|
      table.with_header_two_column(column1_title: "Field", column2_title: "Value", class_names: "text-left")

      table.with_subheader_row(class_names: "subheader-row base-lightest") do |row|
        row.with_data_cell(is_header: true) { "Profile" }
        row.with_data_cell(is_header: true) { "Latest update" }
      end

      table.with_row do |row|
        row.with_data_cell(is_header: true, data_label: "Field") { "Employer" }
        row.with_data_cell(data_label: "Value") { "Patuxent Labs" }
      end

      table.with_row(highlight: true) do |row|
        row.with_data_cell(is_header: true, data_label: "Field") { "Status" }
        row.with_data_cell(data_label: "Value") { "Processing" }
      end

      table.with_row do |row|
        row.with_data_cell(is_header: true, data_label: "Field") { "Pay date" }
        row.with_data_cell(data_label: "Value") { "August 15, 2023" }
      end

      table.with_row do |row|
        row.with_data_cell(is_header: true, data_label: "Field") { "Net pay" }
        row.with_data_cell(data_label: "Value") { "$1,950.25" }
      end
    end
  end
end
