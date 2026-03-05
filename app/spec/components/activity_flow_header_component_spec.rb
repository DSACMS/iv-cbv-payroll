# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityFlowHeaderComponent, type: :component do
  subject(:component) { described_class.new(title: title, exit_url: exit_url) }

  let(:exit_url) { "/activities" }
  let(:title) { "Employment" }


  it "renders the activity title" do
    render_inline(component)
    expect(page).to have_text(title)
  end

  it "renders the Exit link" do
    render_inline(component)
    expect(page).to have_text(I18n.t("activities.activity_header_component.exit"))
  end

  it "sets the exit URL as a Stimulus value on the wrapper" do
    render_inline(component)
    expect(page).to have_css("[data-activity-flow-header-exit-url-value='#{exit_url}']")
  end

  it "renders the exit confirmation modal" do
    render_inline(component)
    expect(page).to have_css("#exit-confirmation-modal")
    expect(page).to have_text(I18n.t("activities.activity_header_component.modal.heading"))
    expect(page).to have_text(I18n.t("activities.activity_header_component.modal.body"))
    expect(page).to have_text(I18n.t("activities.activity_header_component.modal.back_button"))
    expect(page).to have_text(I18n.t("activities.activity_header_component.modal.exit_link"))
  end

  it "does not render back-nav when back_url is nil" do
    render_inline(component)
    expect(page).not_to have_css(".back-nav")
  end

  context "when back_url is provided" do
    subject(:component) { described_class.new(title: title, exit_url: exit_url, back_url: "/previous") }

    it "renders the Back link" do
      render_inline(component)
      expect(page).to have_css(".back-nav")
      expect(page).to have_link(I18n.t("activities.activity_header_component.back"), href: "/previous")
    end
  end
end
