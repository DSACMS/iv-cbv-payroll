# frozen_string_literal: true

require "rails_helper"

RSpec.describe Uswds::ComboBox, type: :component do
  include ApplicationHelper

  let(:options) { us_state_and_territory_options }

  it "renders the combo box wrapper" do
    render_inline(described_class.new(name: "state", options: options))

    expect(page).to have_css("div.usa-combo-box")
  end

  it "renders a select element inside the wrapper" do
    render_inline(described_class.new(name: "state", options: options))

    expect(page).to have_css("div.usa-combo-box select.usa-select")
  end

  it "renders the provided options" do
    render_inline(described_class.new(name: "state", options: options))

    expect(page).to have_css("option", text: "Alabama (AL)")
    expect(page).to have_css("option", text: "Florida (FL)")
    expect(page).to have_css("option", text: "New York (NY)")
  end

  it "renders a label when provided" do
    render_inline(described_class.new(name: "state", options: options, label: "State"))

    expect(page).to have_css("label.usa-label", text: "State")
  end

  it "when selected is given, marks that option and sets data-default-value" do
    render_inline(described_class.new(name: "state", options: options, selected: "FL"))

    expect(page).to have_css("option[selected][value='FL']")
    expect(page).to have_css("div.usa-combo-box[data-default-value='FL']")
  end

  it "includes a blank default option" do
    render_inline(described_class.new(name: "state", options: options))

    expect(page).to have_css("option[value='']", text: "- Select -")
  end
end
