require "rails_helper"

RSpec.describe "Employment month selection errors", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation, client_agency_id: "sandbox") }
  let(:flow) { invitation.activity_flows.order(:created_at).last }

  before do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 1)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: I18n.t("shared.benefit.sandbox")))
  end

  after do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  context "with employment month selection" do
    let(:activity) { create(:employment_activity, activity_flow: flow) }
    let(:title) { I18n.t("activities.employment.month_selections.edit.title", employer_name: activity.employer_name) }

    before do
      flow.update!(reporting_window_months: 3)
      visit edit_activities_flow_income_employment_month_selection_path(employment_id: activity)
      verify_page(page, title: title)
      click_button I18n.t("activities.employment.month_selections.edit.continue")
    end

    it "keeps the visible selection instruction below the slim error banner" do
      # Wait for the error before running accessibility checks on the same page title.
      expect(page).to have_selector(".usa-alert--error.usa-alert--slim",
        text: I18n.t("activities.employment.month_selections.edit.error_body"), count: 1)
      verify_page(page, title: title)
      expect(page).to have_no_selector(".usa-alert__heading")
      expect(page).to have_selector(".usa-alert--slim:focus[data-error-summary-form-id-value='employment_month_selection_form']")
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
      expect(page).to have_selector("legend:not(.usa-sr-only)", text: I18n.t("activities.employment.month_selections.edit.legend"))
      expect(page).to have_selector("input[type='checkbox']", count: 3, visible: :all)
      expect(activity.reload.selected_months).to be_empty
    end
  end
end
