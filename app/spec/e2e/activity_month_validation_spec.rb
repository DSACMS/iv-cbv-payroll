require "rails_helper"

RSpec.describe "Work program month validation", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation, client_agency_id: "sandbox") }
  let(:flow) { invitation.activity_flows.order(:created_at).last }
  let(:activity) { create(:job_training_activity, activity_flow: flow) }
  let(:scope) { "activities.work_programs.hours_input" }
  let(:month_label) { I18n.l(flow.reporting_months.last, format: :month_year) }
  let(:title) { I18n.t("#{scope}.heading", month: month_label, organization: activity.program_name) }

  before do
    visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 2)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: I18n.t("shared.benefit.sandbox")))
    create(:job_training_activity_month, job_training_activity: activity, month: flow.reporting_months.first, hours: 0)
    visit edit_activities_flow_job_training_month_path(job_training_id: activity, id: 1)
    verify_page(page, title: title)
    check "no_hours", allow_label_click: true
    click_button I18n.t("#{scope}.continue")
  end

  it "keeps the inline error until valid hours are submitted" do
    expect(page).to have_selector(".usa-error-message", text: I18n.t("#{scope}.field_error"))
    verify_page(page, title: title)
    expect(page).to have_no_selector(".usa-alert--error")

    fill_in I18n.t("#{scope}.hours_label", month: month_label), with: "12.5"
    expect(page).to have_selector(".usa-error-message", text: I18n.t("#{scope}.field_error"))
    click_button I18n.t("#{scope}.continue")

    verify_page(page, title: I18n.t("activities.document_uploads.new.title", name: activity.program_name), skip_axe_rules: %w[heading-order])
    expect(activity.activity_months.order(:month).pluck(:hours)).to eq([ 0, 12.5 ])
  end
end
