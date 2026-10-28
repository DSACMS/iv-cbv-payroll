require "rails_helper"

RSpec.describe "Activity hub added alert", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:applicant) { create(:cbv_applicant) }
  let(:invitation) { create(:activity_flow_invitation, client_agency_id: "sandbox", cbv_applicant: applicant) }
  let(:activity_flow) { ActivityFlow.last }
  let(:draft) { true }
  let(:activity) { create(:volunteering_activity, activity_flow: activity_flow, draft: draft) }
  let(:alert_text) do
    I18n.t("activities.hub.activity_added",
      activity_type: I18n.t("activities.submit.pdf.activity_types.community_service"))
  end

  before do
    visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 1)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: I18n.t("shared.benefit.sandbox")))
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.title"))
  end

  it "shows the added alert once after completing a new activity" do
    visit review_activities_flow_community_service_path(id: activity)
    verify_page(page, title: I18n.t("activities.community_service.review.title", organization_name: activity.organization_name))
    click_button I18n.t("activities.community_service.review.save")
    verify_page(page, title: I18n.t("activities.hub.title"))

    expect(page).to have_selector(".usa-alert--success.usa-alert--slim", text: alert_text, normalize_ws: true)

    visit current_path
    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_no_selector(".usa-alert--success")
  end

  it "does not show the added alert after canceling a new activity" do
    visit review_activities_flow_community_service_path(id: activity)
    verify_page(page, title: I18n.t("activities.community_service.review.title", organization_name: activity.organization_name))
    click_link I18n.t("activities.activity_header_component.exit")
    within("#exit-confirmation-modal") do
      click_link I18n.t("activities.activity_header_component.modal.exit_link")
    end
    verify_page(page, title: I18n.t("activities.hub.title"))

    expect(page).to have_no_selector(".usa-alert--success")
  end

  context "when editing a published activity" do
    let(:draft) { false }

    it "does not show the added alert after saving changes" do
      visit review_activities_flow_community_service_path(id: activity, from_edit: 1)
      verify_page(page, title: I18n.t("activities.community_service.review.title", organization_name: activity.organization_name))
      click_button I18n.t("activities.hub.save")
      verify_page(page, title: I18n.t("activities.hub.title"))

      expect(page).to have_text(activity.organization_name)
      expect(page).to have_no_selector(".usa-alert--success")
    end
  end

  context "when verified education goes directly to review and submit" do
    let(:education_activity) do
      create(:education_activity, activity_flow: activity_flow, data_source: :validated, status: :succeeded, draft: true)
    end
    let(:alert_text) do
      I18n.t("activities.hub.activity_added", activity_type: I18n.t("activities.submit.pdf.activity_types.education"))
    end

    before do
      create(:nsc_enrollment_term, education_activity: education_activity)
    end

    it "shows the added alert only on the first return to the hub" do
      visit edit_activities_flow_education_path(id: education_activity)
      verify_page(page, title: I18n.t("activities.education.edit.header"))
      click_button I18n.t("activities.education.edit.continue")
      verify_page(page, title: I18n.t("activities.summary.title"))
      expect(page).to have_no_selector(".usa-alert--success")

      click_link I18n.t("activities.activity_header_component.back")
      verify_page(page, title: I18n.t("activities.hub.title"))
      expect(page).to have_selector(".usa-alert--success", text: alert_text, normalize_ws: true)

      click_button I18n.t("activities.hub.review_and_submit")
      verify_page(page, title: I18n.t("activities.summary.title"))
      page.go_back
      verify_page(page, title: I18n.t("activities.hub.title"))
      expect(page).to have_no_selector(".usa-alert--success")
    end
  end
end
