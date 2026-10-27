require "rails_helper"

RSpec.describe "e2e Launcher dedupe test data", :js, type: :feature do
  include E2e::TestHelpers

  before do
    visit launcher_advanced_path
    # Existing advanced-launcher headings and controls lack accessible labels.
    verify_page(page, title: "Emmy Launcher", skip_axe_rules: %w[heading-order label select-name])
    click_button "Fake Test Scenarios"
    choose "test_scenario_partial_enrollment_maya", allow_label_click: true
  end

  it "lets testers inspect the expected records without changing their selection" do
    within ".advanced-launcher__scenario-with-details" do
      find("summary", text: I18n.t("launcher.advanced.duplicate_enrollments.test_data")).click
    end

    expect(page).to have_checked_field("test_scenario_partial_enrollment_maya", visible: :all)
    expect(page).to have_field("reporting_window_months", with: "2")
    within "details" do
      expect(page).to have_selector("tbody tr", count: 5)
      expect(page).to have_selector("tr", text: /Withdrawn \(S\).*Remove duplicate/)
      expect(page).to have_selector("tr", text: /Leave of absence \(A\).*Keep/)
      expect(page).to have_selector("td", text: I18n.t("launcher.advanced.duplicate_enrollments.keep"), count: 3)
      expect(page).to have_selector("td", text: I18n.t("launcher.advanced.duplicate_enrollments.remove"), count: 2)
    end

    choose "test_scenario_duplicate_enrollments_dedupe", allow_label_click: true

    expect(page).to have_checked_field("test_scenario_duplicate_enrollments_dedupe", visible: :all)
    expect(page).to have_field("reporting_window_months", with: "3")
  end
end
