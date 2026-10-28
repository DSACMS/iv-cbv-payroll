require "rails_helper"

RSpec.describe "NSC enrollment statuses", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation) }
  let(:flow) { invitation.activity_flows.order(:created_at).last }
  let(:education) { create(:education_activity, activity_flow: flow) }

  before do
    visit activities_flow_start_path(token: invitation.auth_token)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: I18n.t("shared.benefit.sandbox")))
    flow.update!(identity: create(:identity, :nsc_lynette), created_at: Date.new(2024, 7, 15), reporting_window_months: 6)
    nsc_stub_token_request
    nsc_stub_request_education_search_response("lynette") do |response|
      enrollment = response.fetch("enrollmentDetails").first
      template = enrollment.fetch("enrollmentData").first
      enrollment["enrollmentData"] = %w[F Q H L Y A W S G D].map do |code|
        template.merge("enrollmentStatus" => code)
      end
    end
    NscDataFetcherService.new(education_activity: education, environment: :test).fetch
    visit edit_activities_flow_education_path(id: education)
    verify_page(page, title: I18n.t("activities.education.edit.header"))
  end

  it "shows the new labels and combines school and Clearinghouse withdrawals" do
    expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.enrolled"))
    expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.leave_of_absence"))
    expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.graduated"))
    expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.deceased"))
    expect(page).to have_selector("td", exact_text: I18n.t("components.enrollment_term_table_component.status.withdrawn"), count: 1)
    expect(education.nsc_enrollment_terms.count).to eq(9)
  end
end
