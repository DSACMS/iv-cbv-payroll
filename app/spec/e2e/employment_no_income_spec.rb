require "rails_helper"

RSpec.describe "CE paid work without income", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:applicant) { create(:cbv_applicant, first_name: "Example", last_name: "Member") }
  let(:invitation) { create(:activity_flow_invitation, client_agency_id: "sandbox", cbv_applicant: applicant) }
  let(:flow) { ActivityFlow.last }
  let(:activity) { create(:employment_activity, activity_flow: flow, employer_name: "Example Employer", selected_months: [ flow.reporting_months.first ]) }
  let(:monthly_title) { I18n.t("activities.employment.hours_input.heading", organization: activity.employer_name) }
  let(:banner_text) do
    ActionView::Base.full_sanitizer.sanitize(
      I18n.t("activities.employment.hours_input.error_body_html", month_selection_url: "")
    )
  end

  before do
    visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 3)
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.title"))
    visit edit_activities_flow_income_employment_month_path(employment_id: activity, id: 0)
    verify_page(page, title: monthly_title)
  end

  it "lets the user return to month selection after submitting no income" do
    expect(page).to have_no_selector(".usa-alert--info")
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: I18n.l(flow.reporting_months.first, format: :month)), with: "0"
    click_button I18n.t("activities.employment.hours_input.continue")
    verify_page(page, title: monthly_title)

    expect(page).to have_selector(".usa-alert--info", text: banner_text)
    reporting_for = find("div", text: I18n.t("activities.reporting_for.text_html", name: "Example Member"), exact_text: true)
    banner = find(".usa-alert--info")
    expect(banner.native.rect.y + banner.native.rect.height).to be <= reporting_for.native.rect.y
    expect(page).to have_no_selector(".usa-alert--error")
    expect(page).to have_selector(".usa-error-message", text: I18n.t("activities.employment.hours_input.field_error"))
    within(".usa-alert--info") do
      click_link "edit the months you selected"
    end
    verify_page(page, title: I18n.t("activities.employment.month_selections.edit.title", employer_name: activity.employer_name))
    expect(page).to have_field(I18n.l(flow.reporting_months.first, format: :month_year), checked: true, visible: :all)
  end
end
