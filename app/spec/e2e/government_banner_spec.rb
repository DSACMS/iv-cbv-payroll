require "rails_helper"

RSpec.describe "Government banner", :js, type: :feature do
  include E2e::TestHelpers

  before do
    allow_any_instance_of(ActionDispatch::Request).to receive(:ssl?).and_return(true)
    allow_any_instance_of(ActionDispatch::Request).to receive(:host).and_return("example.gov")
  end

  it "expands and collapses the official website guidance" do
    visit root_path
    verify_page(page, title: I18n.t("pages.home.header"))

    expect(page).to have_no_text(I18n.t("application.government_banner.gov_heading"))
    click_button I18n.t("application.government_banner.how_you_know")
    expect(page).to have_text(I18n.t("application.government_banner.gov_heading"))
    expect(page).to have_text(I18n.t("application.government_banner.https_heading"))
    expect(page).to be_axe_clean

    click_button I18n.t("application.government_banner.how_you_know")
    expect(page).to have_no_text(I18n.t("application.government_banner.gov_heading"))
  end
end
