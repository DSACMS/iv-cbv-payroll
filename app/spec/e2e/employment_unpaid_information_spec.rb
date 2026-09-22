require "rails_helper"

RSpec.describe "Unpaid employment information", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  it "preserves unpaid work through validation, saving, and editing" do
    invitation = create(:activity_flow_invitation, client_agency_id: "sandbox")
    visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 3)
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.empty_state_title"))
    within("[data-activity-type='employment']") do
      click_button I18n.t("activities.hub.add")
    end
    verify_page(page, title: I18n.t("activities.employment.add_your_work.show.header"))
    choose I18n.t("activities.employment.add_your_work.show.options.unpaid.label"), allow_label_click: true
    click_button I18n.t("continue")
    title = I18n.t("activities.employment_info.unpaid_or_in_kind.title")
    verify_page(page, title: title)

    accordion_title = I18n.t("activities.employment_info.unpaid_or_in_kind.accordion.title")
    accordion_content = I18n.t("activities.employment_info.unpaid_or_in_kind.accordion.item_1")
    expect(page).to have_no_text(accordion_content)
    click_button accordion_title
    expect(page).to have_text(accordion_content)
    click_button accordion_title
    expect(page).to have_no_text(accordion_content)
    expect(page).to have_no_field(I18n.t("activities.employment_info.self_employed"))

    click_button I18n.t("activities.employment_info.continue")
    verify_page(page, title: title)
    expect(page).to have_text(I18n.t("activities.employment_info.unpaid_or_in_kind.employer_name_error"))
    fill_in I18n.t("activities.employment_info.unpaid_or_in_kind.employer_name"), with: "Example work"
    fill_in I18n.t("activities.employment_info.unpaid_or_in_kind.contact_name"), with: "Example contact"
    click_button I18n.t("activities.employment_info.continue")
    verify_page(page, title: I18n.t("activities.employment.month_selections.edit.title", employer_name: "Example work"))

    activity = EmploymentActivity.last
    expect(activity).to be_unpaid_or_in_kind
    visit edit_activities_flow_income_employment_path(id: activity)
    verify_page(page, title: title)
    expect(page).to have_field(I18n.t("activities.employment_info.unpaid_or_in_kind.contact_name"), with: "Example contact")
  end
end
