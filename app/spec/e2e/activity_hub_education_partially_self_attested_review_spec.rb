require "rails_helper"

RSpec.describe "e2e Education partially self-attested review flow", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  around do |ex|
    override_supported_providers([ :argyle ]) do
      e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      e2e.use_recording("e2e_activity_flow", &ex)
    end
  end

  it "renders mixed enrollment details and saves back to the hub" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
    # Start at the activity hub
    visit URI(root_url).request_uri
    visit activities_flow_entry_path(client_agency_id: "sandbox")
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.title"))

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

    expect(page).to have_content(I18n.t("activities.education.review.enrollment_information_numbered", number: 1))
    expect(page).to have_content(I18n.t("activities.education.review.enrollment_information_numbered", number: 2))
    expect(page).to have_selector("h3", text: I18n.t("activities.education.review.credit_hours_section"), count: 1)
    expect(page).to have_content(I18n.t("activities.education.review.community_engagement_hours"))
    expect(page).to have_content(I18n.t("activities.education.review.ce_explainer_title"))

    # --- Step 2: Save and return to the hub ---
    click_button I18n.t("activities.education.review.save")
    verify_page(page, title: I18n.t("activities.hub.title"))
  end
end
