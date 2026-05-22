require "rails_helper"
require "percy/capybara" if ENV["PERCY_VISUAL_RUN"] == "1"

RSpec.describe "Percy visual snapshots", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  before do
    skip "Set PERCY_VISUAL_RUN=1 to run Percy visual snapshots" unless ENV["PERCY_VISUAL_RUN"] == "1"
  end

  it "captures the applicant information page" do
    # Establish a CBV flow session before visiting the page we want to snapshot.
    visit cbv_flow_new_path(client_agency_id: "sandbox")
    visit cbv_flow_applicant_information_path

    verify_page(page, title: I18n.t("cbv.applicant_informations.show.your_information"))
    expect(page).to have_text(I18n.t("cbv.applicant_informations.show.your_information"))

    page.percy_snapshot("CBV applicant information")
  end

  it "captures the activity hub empty state" do
    # Drive through the entry page into the empty Activity Hub state.
    visit activities_flow_entry_path(client_agency_id: "sandbox")
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    click_link I18n.t("activities.entries.show.continue")

    verify_page(page, title: I18n.t("activities.hub.empty_state_title"))
    expect(page).to have_text(I18n.t("activities.hub.empty_state_title"))

    page.percy_snapshot("Activity Hub empty state")
  end
end
