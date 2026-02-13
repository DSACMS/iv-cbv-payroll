require_relative "smoke_helper"

RSpec.describe "Employer search", type: :feature do
  before do
    visit_site("sandbox", "/cbv/links/sandbox")
    complete_entry_page
  end

  it "can search for an employer and see results" do
    fill_in name: "query", with: "Amazon"
    click_button "Search"

    expect(page).to have_css("div.usa-card__container", wait: 15)
  end

  it "can select an employer from search results" do
    fill_in name: "query", with: "Amazon"
    click_button "Search"

    expect(page).to have_css("div.usa-card__container", wait: 15)
    first("div.usa-card__container").click_button("Select")

    # An aggregator modal should load (either Argyle or Pinwheel)
    has_argyle = page.has_css?("div[id*='argyle-link-root']", visible: :all, wait: 15)
    has_pinwheel = page.has_css?("iframe.pinwheel-modal-show", wait: 0)
    expect(has_argyle || has_pinwheel).to be true
  end

  it "can select an employer from a popular tile" do
    click_button "Paychex"

    # Paychex is an Argyle employer — the Argyle modal should load
    expect(page).to have_css("div[id*='argyle-link-root']", visible: :all, wait: 20)
  end
end
