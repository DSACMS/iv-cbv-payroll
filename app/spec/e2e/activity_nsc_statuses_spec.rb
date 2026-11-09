require "rails_helper"

RSpec.describe "NSC enrollment statuses", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation) }
  let(:flow) { invitation.activity_flows.order(:created_at).last }
  let(:education) { create(:education_activity, activity_flow: flow) }
  let(:enrollment_codes) { %w[F Q H L Y A W S G D] }

  before do
    visit activities_flow_start_path(token: invitation.auth_token)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: I18n.t("shared.benefit.sandbox")))
    flow.update!(identity: create(:identity, :nsc_lynette), created_at: Date.new(2024, 7, 15), reporting_window_months: 6)
    nsc_stub_token_request
    nsc_stub_request_education_search_response("lynette") do |response|
      enrollment = response.fetch("enrollmentDetails").first
      template = enrollment.fetch("enrollmentData").first
      enrollment["enrollmentData"] = enrollment_codes.map do |code|
        template.merge("enrollmentStatus" => code)
      end
    end
    NscDataFetcherService.new(education_activity: education, environment: :test).fetch
    visit edit_activities_flow_education_path(id: education)
    verify_page(page, title: I18n.t("activities.education.edit.header"))
  end

  it "hides enrolled, shows other statuses, and combines school and Clearinghouse withdrawals" do
    click_button I18n.t("activities.education.edit.enrollment_history")

    expect(page).to have_no_text(I18n.t("components.enrollment_term_table_component.status.enrolled"))
    expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.leave_of_absence"))
    expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.graduated"))
    expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.deceased"))
    expect(page).to have_selector("td", text: I18n.t("components.enrollment_term_table_component.status.withdrawn"), count: 1)
    expect(education.nsc_enrollment_terms.count).to eq(9)
  end

  context "when NSC returns only enrolled" do
    let(:enrollment_codes) { %w[Y] }
    let(:term) { education.nsc_enrollment_terms.sole }

    it "shows the enrollment details without a status row" do
      expect(page).to have_selector("tr", text: I18n.t("components.enrollment_term_table_component.student_name_label"))
      expect(page).to have_selector("tr", text: I18n.t("components.enrollment_term_table_component.school_or_program"))
      expect(page).to have_selector("tr", text: I18n.t("components.enrollment_term_table_component.enrollment_term"))
      expect(page).to have_no_selector("tr", text: I18n.t("components.enrollment_term_table_component.enrollment_status"))
    end

    it "collects supplemental details and lets the applicant edit their enrollment status" do
      term.update!(credit_hours: 0)
      create(:nsc_enrollment_term, education_activity: education, enrollment_status: "half_time")
      visit edit_activities_flow_education_term_credit_hour_path(education_id: education, id: 0, from_review: 1, from_edit: 1)
      heading = I18n.t("activities.education.term_credit_hours.heading", school_name: term.school_name.titlecase)
      status_label = I18n.t("activities.education.add_your_term.edit.enrollment_status")
      hours_label = I18n.t("activities.education.add_your_term.edit.credit_hours")
      no_classes_label = I18n.t("activities.education.term_credit_hours.no_hours_checkbox", school_name: term.school_name.titlecase)
      verify_page(page, title: heading)

      expect(page).to have_field(no_classes_label, checked: true, visible: :all)
      select I18n.t("activities.education.add_your_term.edit.enrollment_status_options.less_than_half_time"), from: status_label
      expect(page).to have_field(no_classes_label, checked: false, visible: :all)
      expect(page).to have_field(hours_label, with: "")
      fill_in hours_label, with: "2.5"
      select I18n.t("activities.education.add_your_term.edit.enrollment_status_options.full_time"), from: status_label
      expect(page).to have_no_field(hours_label)
      check no_classes_label, allow_label_click: true
      expect(page).to have_select(status_label, selected: I18n.t("activities.education.add_your_term.edit.select_one"))
      select I18n.t("activities.education.add_your_term.edit.enrollment_status_options.unknown"), from: status_label
      expect(page).to have_field(hours_label, with: "")
      fill_in hours_label, with: "2.5"
      click_button I18n.t("activities.hub.save")
      verify_page(page, title: I18n.t("activities.education.review.title_no_school_name"))
      expect(term.reload).to have_attributes(enrollment_status: "enrolled", supplemental_enrollment_status: "unknown", credit_hours: BigDecimal("2.5"))

      click_link I18n.t("activities.education.review.edit")
      verify_page(page, title: heading)
      expect(page).to have_select(status_label, selected: I18n.t("activities.education.add_your_term.edit.enrollment_status_options.unknown"))
      select I18n.t("activities.education.add_your_term.edit.enrollment_status_options.half_time"), from: status_label
      click_button I18n.t("activities.hub.save")
      verify_page(page, title: I18n.t("activities.education.review.title_no_school_name"))
      expect(term.reload).to have_attributes(enrollment_status: "enrolled", supplemental_enrollment_status: "half_time", credit_hours: nil)
    end
  end

  context "when NSC returns only less than half-time" do
    let(:enrollment_codes) { %w[L] }

    it "collects credit hours without asking for an enrollment status" do
      click_button I18n.t("activities.education.edit.continue")
      term = education.nsc_enrollment_terms.sole
      verify_page(page, title: I18n.t("activities.education.term_credit_hours.heading", school_name: term.school_name.titlecase))

      expect(page).to have_field(I18n.t("activities.education.add_your_term.edit.credit_hours"))
      expect(page).to have_text(I18n.t("activities.education.add_your_term.edit.credit_hours_hint"))
      expect(page).to have_no_select(I18n.t("activities.education.add_your_term.edit.enrollment_status"))
    end
  end
end
