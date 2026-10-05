require "rails_helper"

RSpec.describe "Employment-focused entry navigation", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation, employment_focused: true) }

  it "renders the employment-focused entry content and navigates to add-your-work screen" do
    visit activities_flow_start_path(token: invitation.auth_token)

    verify_page(page, title: I18n.t("activities.entries.show.employment_focused.header"))
    expect(page).to have_no_content(I18n.t("activities.entries.show.title", benefit: "Medicaid"))

    click_link I18n.t("activities.entries.show.employment_focused.get_started")

    verify_page(page, title: "Choose how you want to add your job")
    expect(page).to have_no_text("Choose how you want to add your work")
    expect(page).to have_selector("label .text-bold", text: "Enter in-kind work", exact_text: true)
    expect(page).to have_no_text("Enter unpaid or in-kind work")
    expect(page).to have_selector("strong", text: "Reporting period:")
    expect(page).to have_text(ActivityFlow.last.reporting_window_display)
  end

  it "renders the generic entry content when not employment_focused" do
    non_employment_invitation = create(:activity_flow_invitation, employment_focused: false)
    visit activities_flow_start_path(token: non_employment_invitation.auth_token)

    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    expect(page).to have_no_content(I18n.t("activities.entries.show.employment_focused.header"))

    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.empty_state_title"))
    within("[data-activity-type='employment']") { click_button I18n.t("activities.hub.add") }
    verify_page(page, title: "Choose how you want to add your work")
    expect(page).to have_no_text("Choose how you want to add your job")
    expect(page).to have_selector("label .text-bold", text: "Enter unpaid or in-kind work", exact_text: true)
  end
end
