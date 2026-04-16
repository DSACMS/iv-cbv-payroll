require "rails_helper"

RSpec.describe "e2e Education mixed enrollment review flow", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  around do |ex|
    override_supported_providers([ :argyle ]) do
      e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      e2e.use_recording("e2e_activity_flow", &ex)
    end
  end

  it "renders mixed enrollment details and routes to review and submit when half-time coverage is present" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
    # Start at the activity hub
    visit URI(root_url).request_uri
    visit activities_flow_entry_path(client_agency_id: "sandbox")
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.empty_state_title"))

    # Seed a partially self-attested education activity with mixed enrollments
    flow = ActivityFlow.last
    education_activity = create(
      :education_activity,
      activity_flow: flow,
      data_source: :partially_self_attested,
      status: :succeeded
    )

    create(
      :nsc_enrollment_term,
      :less_than_half_time,
      education_activity: education_activity,
      school_name: "Riverside Community College",
      credit_hours: 4
    )
    create(
      :nsc_enrollment_term,
      education_activity: education_activity,
      school_name: "Pine Valley College",
      enrollment_status: :half_time
    )

    # --- Step 1: Review partially self-attested activity ---
    visit review_activities_flow_education_path(id: education_activity)
    verify_page(
      page,
      title: I18n.t("activities.education.review.title_no_school_name")
    )

    expect(page).to have_content(
      I18n.t("activities.education.review.enrollment_information_numbered", number: 1)
    )
    expect(page).to have_content(
      I18n.t("activities.education.review.enrollment_information_numbered", number: 2)
    )
    expect(page).to have_selector("h3", text: I18n.t("activities.education.review.credit_hours_section"), count: 1)
    expect(page).to have_content(I18n.t("activities.education.review.community_engagement_hours"))
    expect(page).to have_content(I18n.t("activities.education.review.ce_explainer_title"))
    expect(page).to have_content(
      I18n.t(
        "activities.education.review.description",
        school_name: "Pine Valley College and Riverside Community College"
      )
    )
    expect(page).to have_content(
      I18n.t(
        "activities.education.review.additional_comments_description",
        agency_name: I18n.t("shared.agency_full_name.sandbox")
      )
    )
    # --- Step 2: Save and continue to review and submit ---
    click_button I18n.t("activities.education.review.save")
    verify_page(page, title: I18n.t("activities.summary.title", benefit: I18n.t("shared.benefit.sandbox")))
  end

  it "shows same-school less-than-half-time enrollments in one collapsed table on review and submit" do
    visit URI(root_url).request_uri
    visit activities_flow_entry_path(client_agency_id: "sandbox")
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.empty_state_title"))

    current_flow = ActivityFlow.order(created_at: :desc).first
    education_activity = create(
      :education_activity,
      activity_flow: current_flow,
      data_source: :partially_self_attested,
      status: :succeeded
    )
    create(
      :nsc_enrollment_term,
      :less_than_half_time,
      education_activity: education_activity,
      first_name: "Maya",
      last_name: "Testuser",
      school_name: "River College",
      term_begin: Date.new(2026, 1, 1),
      term_end: Date.new(2026, 1, 31)
    )
    create(
      :nsc_enrollment_term,
      :less_than_half_time,
      education_activity: education_activity,
      first_name: "Maya",
      last_name: "Testuser",
      school_name: "River College",
      term_begin: Date.new(2026, 2, 1),
      term_end: Date.new(2026, 2, 28)
    )

    visit activities_flow_root_path
    verify_page(page, title: I18n.t("activities.hub.in_progress_state_title"))
    click_button I18n.t("activities.hub.review_and_submit")
    verify_page(page, title: I18n.t("activities.summary.title", benefit: I18n.t("shared.benefit.sandbox")))

    expect(page).to have_selector(
      "table tr",
      text: /#{Regexp.escape(I18n.t("components.enrollment_term_table_component.school_or_program"))}.*River College/,
      count: 1
    )
  end

  it "saves back to the activity hub when no half-time coverage is present" do # rubocop:disable RSpec/MultipleExpectations
    visit URI(root_url).request_uri
    visit activities_flow_entry_path(client_agency_id: "sandbox")
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.empty_state_title"))

    flow = ActivityFlow.last
    education_activity = create(
      :education_activity,
      activity_flow: flow,
      data_source: :partially_self_attested,
      status: :succeeded
    )

    first_month = flow.reporting_months.first
    second_month = flow.reporting_months.second

    create(
      :nsc_enrollment_term,
      :less_than_half_time,
      education_activity: education_activity,
      school_name: "Riverside Community College",
      credit_hours: 4,
      term_begin: first_month,
      term_end: second_month.end_of_month
    )

    visit review_activities_flow_education_path(id: education_activity)
    verify_page(
      page,
      title: I18n.t("activities.education.review.title_no_school_name")
    )

    click_button I18n.t("activities.education.review.save")
    verify_page(page, title: I18n.t("activities.hub.in_progress_state_title"))
    expect(page).to have_button(I18n.t("activities.hub.review_and_submit"))
  end
end
