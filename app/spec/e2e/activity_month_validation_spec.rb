require "rails_helper"

RSpec.describe "Community service and work program month validation", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation, client_agency_id: "sandbox") }
  let(:flow) { invitation.activity_flows.order(:created_at).last }

  before do
    visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 2)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: I18n.t("shared.benefit.sandbox")))
  end

  context "with community service" do
    let(:activity) { create(:volunteering_activity, activity_flow: flow, organization_name: "Helping Hands") }
    let(:scope) { "activities.community_service.hours_input" }
    let(:activity_name) { activity.organization_name }

    it "requires an organization name with an inline error" do
      visit new_activities_flow_community_service_path
      verify_page(page, title: I18n.t("activities.community_service.new_title"))
      click_button I18n.t("activities.community_service.continue")

      expect(page).to have_selector("#volunteering_activity_organization_name_error",
        text: I18n.t("activerecord.errors.models.volunteering_activity.attributes.organization_name.blank"))
      verify_page(page, title: I18n.t("activities.community_service.new_title"))
      expect(flow.volunteering_activities).to be_empty
    end

    it "shows an inline error only when the last month leaves all months without hours" do
      visit edit_activities_flow_community_service_month_path(community_service_id: activity, id: 0)
      submit_months_without_hours
      correct_last_month

      verify_page(page, title: I18n.t("activities.document_uploads.new.title", name: activity_name), skip_axe_rules: %w[heading-order])
      expect(activity.activity_months.order(:month).pluck(:hours)).to eq([ 0, 12.5 ])
    end
  end

  context "with a work program" do
    let(:activity) { create(:job_training_activity, activity_flow: flow, program_name: "Career Training") }
    let(:scope) { "activities.work_programs.hours_input" }
    let(:activity_name) { activity.program_name }

    it "shows an inline error only when the last month leaves all months without hours" do
      visit edit_activities_flow_job_training_month_path(job_training_id: activity, id: 0)
      submit_months_without_hours
      correct_last_month

      verify_page(page, title: I18n.t("activities.document_uploads.new.title", name: activity_name), skip_axe_rules: %w[heading-order])
      expect(activity.activity_months.order(:month).pluck(:hours)).to eq([ 0, 12.5 ])
    end
  end

  def month_title(month)
    I18n.t("#{scope}.heading", month: I18n.l(month, format: :month_year), organization: activity_name)
  end

  def submit_months_without_hours
    verify_page(page, title: month_title(flow.reporting_months.first))
    expect(page).to have_no_selector(".usa-error-message")
    click_button I18n.t("#{scope}.continue")

    verify_page(page, title: month_title(flow.reporting_months.last))
    expect(page).to have_no_selector(".usa-error-message")
    check "no_hours", allow_label_click: true
    click_button I18n.t("#{scope}.continue")

    expect(page).to have_selector(".usa-error-message", text: I18n.t("#{scope}.field_error"))
    verify_page(page, title: month_title(flow.reporting_months.last))
    expect(page).to have_no_selector(".usa-alert--error")
  end

  def correct_last_month
    fill_in I18n.t("#{scope}.hours_label", month: I18n.l(flow.reporting_months.last, format: :month_year)), with: "12.5"
    expect(page).to have_selector(".usa-error-message", text: I18n.t("#{scope}.field_error"))
    click_button I18n.t("#{scope}.continue")
  end
end
