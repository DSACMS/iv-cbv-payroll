# frozen_string_literal: true

require "rails_helper"

RSpec.describe AccordionComponent, type: :component do
  it "renders content as expected" do
    render_inline(described_class.new(id: "accordion1", expanded: true)) do |component|
      component.with_title { "Accordion Title" }
      component.with_accordion_item { "Expanded Content" }
    end

    button = page.find(:css, "button.usa-accordion__button")
    expect(button["aria-expanded"]).to eq("true")
    expect(page).to have_content("Accordion Title")
    expect(page).to have_content("Expanded Content")
  end

  it "shows content as expanded when expanded is true" do
    render_inline(described_class.new(id: "accordion1", expanded: true)) do |component|
      component.with_title { "Accordion Title" }
      component.with_accordion_item { "Expanded Content" }
    end

    button = page.find(:css, "button.usa-accordion__button")
    expect(button["aria-expanded"]).to eq("true")
    expect(page).to have_content("Expanded Content")
  end

  it "does not show content as expanded when expanded is false or not passed" do
    render_inline(described_class.new(id: "accordion2")) do |component|
      component.with_title { "Accordion Title" }
      component.with_accordion_item { "Collapsed Content" }
    end

    button = page.find(:css, "button.usa-accordion__button")
    expect(button["aria-expanded"]).to eq("false")
  end
end
