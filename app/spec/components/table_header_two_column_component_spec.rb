# frozen_string_literal: true

require "rails_helper"

RSpec.describe TableHeaderTwoColumnComponent, type: :component do
  it "renders content as expected" do
    render_inline(described_class.new(column1_title: "column 1", column2_title: "column 2"))

    expect(page).to have_content("column 1")
    expect(page).to have_content("column 2")
  end
end
