# frozen_string_literal: true

class TableComponentPreview < ApplicationPreview
  def default
    render(TableComponent.new) do |table|
      table.with_header_cell { "Field" }
      table.with_header_cell { "Value" }

      table.with_row do |row|
        row.with_data_cell(is_header: true) { "Employer" }
        row.with_data_cell(data_label: "Employer") { "Patuxent Labs" }
      end

      table.with_row do |row|
        row.with_data_cell(is_header: true) { "Net pay" }
        row.with_data_cell(data_label: "Net pay") { "$1,950.25" }
      end
    end
  end

  def subdued_header
    render(TableComponent.new(subdued_header: true)) do |table|
      table.with_header_cell { "Field" }
      table.with_header_cell { "Value" }

      table.with_row do |row|
        row.with_data_cell(is_header: true) { "Employer" }
        row.with_data_cell(data_label: "Employer") { "Patuxent Labs" }
      end

      table.with_row do |row|
        row.with_data_cell(is_header: true) { "Net pay" }
        row.with_data_cell(data_label: "Net pay") { "$1,950.25" }
      end
    end
  end

  def multi_column
    render(TableComponent.new(multi_column: true)) do |table|
      table.with_header_cell { "Month" }
      table.with_header_cell { "Gross income" }
      table.with_header_cell { "Hours worked" }

      table.with_row do |row|
        row.with_data_cell(is_header: true, data_label: "Month") { "January" }
        row.with_data_cell(data_label: "Gross income") { "$2,100.00" }
        row.with_data_cell(data_label: "Hours worked") { "36" }
      end

      table.with_row do |row|
        row.with_data_cell(is_header: true, data_label: "Month") { "February" }
        row.with_data_cell(data_label: "Gross income") { "$1,875.50" }
        row.with_data_cell(data_label: "Hours worked") { "32" }
      end
    end
  end

  def activity_hours_review
    render(TableComponent.new(activity_hours_review: true)) do |table|
      table.with_header_cell { "Month" }
      table.with_header_cell { "Community engagement hours" }
      table.with_header_cell { "Edit" }

      table.with_row do |row|
        row.with_data_cell(is_header: true, data_label: "Month") do
          content_tag("span", "January") + content_tag("a", "Edit", href: "#", class: "usa-link mobile-edit-link")
        end
        row.with_data_cell(data_label: "Community engagement hours") { "18" }
        row.with_data_cell(class_names: "desktop-edit-link") { content_tag("a", href: "#") { "Edit" } }
      end

      table.with_row do |row|
        row.with_data_cell(is_header: true, data_label: "Month") do
          content_tag("span", "February") + content_tag("a", "Edit", href: "#", class: "usa-link mobile-edit-link")
        end
        row.with_data_cell(data_label: "Community engagement hours") { "18" }
        row.with_data_cell(class_names: "desktop-edit-link") { content_tag("a", href: "#") { "Edit" } }
      end
    end
  end
end
