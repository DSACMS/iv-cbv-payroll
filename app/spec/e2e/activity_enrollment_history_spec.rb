require "rails_helper"

RSpec.describe "Student enrollment history", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation) }
  let(:flow) { invitation.activity_flows.order(:created_at).last }
  let(:education) { create(:education_activity, activity_flow: flow, status: :succeeded) }

  before do
    visit activities_flow_start_path(token: invitation.auth_token)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    profile = Launcher::FakeNscScenarios.by_key("enrollment_history_robin")
    identity = create(:identity, first_name: profile.first_name, last_name: profile.last_name, date_of_birth: profile.date_of_birth)
    flow.update!(identity: identity, created_at: Time.zone.local(2026, 10, 1), reporting_window_months: 2)
    Launcher::FakeNscDataFetcherService.new(education_activity: education).fetch
  end

  it "shows the latest status and lets the user expand and collapse history on mobile" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit edit_activities_flow_education_path(id: education)
    verify_page(page, title: I18n.t("activities.education.edit.header"))

    expect(page).to have_text("Withdrawn (As of September 1, 2026)", normalize_ws: true)
    expect(page).to have_no_text("Enrolled (As of August 1, 2026)", normalize_ws: true)
    click_button "View enrollment history"
    expect(page).to have_text("Enrolled (As of August 1, 2026)", normalize_ws: true)
    expect(page).to have_selector("button[aria-expanded='true']", text: "View enrollment history")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    click_button "View enrollment history"
    expect(page).to have_no_text("Enrolled (As of August 1, 2026)", normalize_ws: true)
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  it "uses horizontal rules without boxes or column headings in both enrollment tables" do
    visit edit_activities_flow_education_path(id: education)
    verify_page(page, title: I18n.t("activities.education.edit.header"))
    click_button "View enrollment history"

    expect(page).to have_no_selector("table.details-table thead", visible: true)
    page.all("table.details-table", count: 2).each do |table|
      borders = page.evaluate_script(<<~JS, table)
        [getComputedStyle(arguments[0]).borderLeftWidth,
         getComputedStyle(arguments[0].querySelector("tbody td")).borderLeftWidth,
         getComputedStyle(arguments[0].querySelector("tbody tr")).borderTopWidth]
      JS
      expect(borders).to eq([ "0px", "0px", "2px" ])
    end
  end
end
