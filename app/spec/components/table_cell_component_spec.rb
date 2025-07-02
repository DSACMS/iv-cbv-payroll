# frozen_string_literal: true

require "rails_helper"

RSpec.describe TableCellComponent, type: :component do
  subject(:result) { render_inline(described_class.new(**options)) { "Cell" } }
  let(:options) { {} }

  it "renders a default <td> with text" do
    expect(result).to have_css(:td, text: "Cell")
  end

  context "with class_names" do
    let(:options) { { class_names: "test" }}

    it "adds class_names to the element" do
      expect(result).to have_css("td.test")
    end
  end

  context "when is_header is true" do
    let(:options) { { is_header: true } }

    it "renders a <th>" do
      expect(result).to have_css("th", text: "Cell")
    end
  end

  context "with data_label" do
    let(:options) { { data_label: "test" } }

    it "adds data-label attribute" do
      expect(result).to have_css('td[data-label="test"]')
    end
  end

  context "with arbitrary HTML attributes" do
    let(:options) { { attributes: { "data-testid" => "test" } } }

    it "includes them in the element" do
      expect(result).to have_css('td[data-testid="test"]')
    end
  end
end
