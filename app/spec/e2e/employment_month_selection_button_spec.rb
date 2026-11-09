require "rails_helper"

RSpec.describe "Employment month selection button", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation, client_agency_id: "sandbox") }
  let(:flow) { invitation.activity_flows.order(:created_at).last }
  let(:activity) { create(:employment_activity, activity_flow: flow, compensation_type: compensation_type) }
  let(:viewport_width) { 1024 }
  let(:button) { find_button(I18n.t("activities.employment.month_selections.edit.continue")) }
  let(:button_width) { button.native.rect.width }
  let(:container_width) { find("#employment_month_selection_form fieldset").native.rect.width }

  before do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: viewport_width, height: 900, deviceScaleFactor: 1, mobile: viewport_width < 1024)
    visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 3)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: I18n.t("shared.benefit.sandbox")))
    visit edit_activities_flow_income_employment_month_selection_path(employment_id: activity)
    verify_page(page, title: I18n.t("activities.employment.month_selections.edit.title", employer_name: activity.employer_name))
  end

  after do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  context "with paid employment" do
    let(:compensation_type) { :paid }

    it "sizes the desktop button to its content" do
      expect(button_width).to be < container_width / 2
    end

    context "on mobile" do
      let(:viewport_width) { 390 }

      it "keeps the button full-width" do
        expect(button_width).to be_within(1).of(container_width)
      end
    end
  end

  context "with unpaid or in-kind employment" do
    let(:compensation_type) { :unpaid_or_in_kind }

    it "sizes the desktop button to its content" do
      expect(button_width).to be < container_width / 2
    end

    context "on mobile" do
      let(:viewport_width) { 390 }

      it "keeps the button full-width" do
        expect(button_width).to be_within(1).of(container_width)
      end
    end
  end
end
