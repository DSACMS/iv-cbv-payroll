# frozen_string_literal: true

require "rails_helper"

RSpec.describe Uswds::IconList, type: :component do
  it "renders items with the default spacing" do
    rendered = render_inline(described_class.new) do |icon_list|
      icon_list.with_item(icon: "groups").with_content("Household members")
    end

    expect(rendered).to have_selector("ul.usa-icon-list.margin-top-2")
    expect(rendered).to have_selector("li.usa-icon-list__item.margin-bottom-1.display-flex.flex-align-center")
    expect(rendered).to have_text("Household members")
  end

  it "accepts custom list and item spacing" do
    rendered = render_inline(described_class.new(class_names: "margin-top-3", item_class_names: "margin-bottom-3")) do |icon_list|
      icon_list.with_item(icon: "groups").with_content("Household members")
    end

    expect(rendered).to have_selector("ul.usa-icon-list.margin-top-3")
    expect(rendered).to have_selector("li.usa-icon-list__item.margin-bottom-3")
  end
end
