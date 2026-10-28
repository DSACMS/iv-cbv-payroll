# frozen_string_literal: true

require "rails_helper"

RSpec.describe Uswds::CurrencyInput, type: :component do
  it "renders the input group wrapper" do
    render_inline(described_class.new(name: "gross_income"))

    expect(page).to have_css("div.usa-input-group")
    expect(page).to have_no_css(".usa-input-group--error")
  end

  it "styles the entire currency group when an error class is supplied" do
    rendered = render_inline(described_class.new(name: "gross_income", group_class: "usa-input-group--error"))

    expect(rendered).to have_selector(".usa-input-group--error .usa-input-prefix")
    expect(rendered).to have_field("gross_income")
  end

  it "renders the currency icon prefix" do
    render_inline(described_class.new(name: "gross_income"))

    expect(page).to have_css("div.usa-input-prefix svg.usa-icon")
  end

  it "renders the provided value" do
    render_inline(described_class.new(name: "gross_income", value: "339"))

    expect(page).to have_css("input[value='339']")
  end
end
