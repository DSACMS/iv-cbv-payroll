# frozen_string_literal: true

require "rails_helper"

RSpec.describe TableComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:table_attributes) { {} }
  let(:rows) { [] }
  let(:base_class) { "usa-table usa-table--borderless width-full" }

  subject(:result) do
    table = described_class.new(attributes: table_attributes)
    rows.each do |row_data|
      table.with_row do |row|
        row.with_data_cell.with_content(row_data)
      end
    end
    render_inline(table)
  end

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
    end
  end

  context "when table attributes are provided" do
    let(:rows) { [ "Cell content" ] }
    let(:table_attributes) { { "data-testid" => "test" } }

    it "renders with assigned attributes" do
      expect(result.css('table[data-testid="test"]')).to be_present
    end
  end
end
