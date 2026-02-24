# frozen_string_literal: true

require "rails_helper"

RSpec.describe Uswds::PhoneInput, type: :component do
  it "renders the input group wrapper" do
    render_inline(described_class.new(name: "phone"))

    expect(page).to have_css("div.usa-input-group")
  end

  it "renders a telephone input" do
    render_inline(described_class.new(name: "phone"))

    expect(page).to have_css("input[type='tel']")
  end

  it "renders the phone icon prefix" do
    render_inline(described_class.new(name: "phone"))

    expect(page).to have_css("div.usa-input-prefix svg.usa-icon")
  end

  it "renders a label when provided" do
    render_inline(described_class.new(name: "phone", label: "Phone number"))

    expect(page).to have_css("label.usa-label", text: "Phone number")
  end

  it "renders the provided value" do
    render_inline(described_class.new(name: "phone", value: "(555) 123-4567"))

    expect(page).to have_css("input[value='(555) 123-4567']")
  end
end
