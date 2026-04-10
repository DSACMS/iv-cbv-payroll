# frozen_string_literal: true

require "rails_helper"

RSpec.describe TableComponent, type: :component do
  include ViewComponent::TestHelpers

  subject(:result) do
    table = described_class.new(attributes: table_attributes)
    rows.each do |row_data|
      table.with_row do |row|
        row.with_data_cell.with_content(row_data)
      end
    end
    render_inline(table)
  end

  let(:table_attributes) { {} }
  let(:rows) { [] }
  let(:base_class) { "usa-table usa-table--borderless usa-table--stacked" }


  context "when no rows are provided" do
    it "does not render the table" do
      result = render_inline(described_class.new)
      expect(result.to_html).to be_empty
    end
  end

  context "when at least one row is provided" do
    let (:rows) { [ "Cell content" ] }

    it "renders a <table> element" do
      expect(result.css("table")).to be_present
      expect(result.text).to include("Cell content")
      expect(result.css("table").first["class"]).to include(base_class)
    end
  end

  context "when table attributes are provided" do
    let(:rows) { [ "Cell content" ] }
    let(:table_attributes) { { "data-testid" => "test" } }

    it "renders with assigned attributes" do
      expect(result.css('table[data-testid="test"]')).to be_present
    end
  end

  context "when header_cells are provided" do
    subject(:result) do
      render_inline(described_class.new) do |table|
        table.with_header_cell(scope: "col") { "Col 1" }
        table.with_header_cell(scope: "col") { "Col 2" }
        table.with_row { |row| row.with_data_cell.with_content("cell") }
      end
    end

    it "renders each header cell inside a thead tr" do
      expect(result.css("thead tr th[scope='col']").length).to eq(2)
      expect(result.css("thead tr th[scope='col']").first.text.strip).to eq("Col 1")
      expect(result.css("thead tr th[scope='col']").last.text.strip).to eq("Col 2")
    end
  end

  context "when header cell content is provided without is_header" do
    subject(:result) do
      render_inline(described_class.new) do |table|
        table.with_header_cell { "Header" }
        table.with_row { |row| row.with_data_cell.with_content("cell") }
      end
    end

    it "renders the slot as a table header cell" do
      expect(result.css("thead tr th").text).to include("Header")
      expect(result.css("thead tr td")).to be_empty
    end
  end
end
