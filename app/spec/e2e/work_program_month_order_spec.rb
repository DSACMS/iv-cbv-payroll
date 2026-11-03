require "rails_helper"

RSpec.describe "Work program month order", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation, client_agency_id: "sandbox") }
  let(:flow) { invitation.activity_flows.order(:created_at).last }
  let(:activity) { create(:job_training_activity, activity_flow: flow) }
  let(:months) { flow.reporting_months }
  let(:first_month_label) { I18n.l(months.first, format: :month_year) }
  let(:scope) { "activities.work_programs.hours_input" }

  before do
    visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 12)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: I18n.t("shared.benefit.sandbox")))
    flow.update!(reporting_window_type: "renewal", created_at: Time.zone.local(2026, 10, 1))

    # Database row order is not guaranteed after edits. Insert out of order to
    # reproduce that condition reliably instead of depending on PostgreSQL's plan.
    months.reverse_each do |month|
      index = months.index(month)
      create(:job_training_activity_month, job_training_activity: activity, month: month,
        hours: index.zero? ? 0 : index + 1)
    end
  end

  it "keeps twelve months chronological on review and upload after editing the first month" do
    visit edit_activities_flow_job_training_month_path(job_training_id: activity, id: 0, from_review: 1)
    verify_page(page, title: I18n.t("#{scope}.heading", month: first_month_label, organization: activity.program_name))
    fill_in I18n.t("#{scope}.hours_label", month: first_month_label), with: "1"
    click_button I18n.t("activities.hub.save")

    verify_page(page, title: I18n.t("activities.work_programs.review.title", program_name: activity.program_name))
    month_order = Regexp.new(months.map { |month| Regexp.escape(I18n.l(month, format: :month_year)) }.join(".*"), Regexp::MULTILINE)
    expect(page).to have_text(month_order)

    visit new_activities_flow_job_training_document_upload_path(job_training_id: activity)
    verify_page(page, title: I18n.t("activities.document_uploads.new.title", name: activity.program_name), skip_axe_rules: %w[heading-order])
    expected_items = months.each_with_index.map do |month, index|
      "#{I18n.l(month, format: :month)} (#{I18n.t('shared.hours', count: index + 1)})"
    end
    expect(page).to have_text(Regexp.new(expected_items.map { |item| Regexp.escape(item) }.join(".*"), Regexp::MULTILINE))
  end
end
