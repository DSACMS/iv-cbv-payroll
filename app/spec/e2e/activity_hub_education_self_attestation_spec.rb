require "rails_helper"

RSpec.describe "e2e Education self-attestation review flow", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  around do |ex|
    override_supported_providers([ :argyle ]) do
      e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      e2e.use_recording("e2e_activity_flow", &ex)
    end
  end

  it "supports editing a self-attested education activity through the full flow" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
    upload_path = Rails.root.join("spec/fixtures/files/document_upload.pdf")

    # Start at the activity hub
    visit URI(root_url).request_uri
    visit activities_flow_entry_path(client_agency_id: "sandbox")
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.empty_state_title"))

    flow = ActivityFlow.last
    month1 = flow.reporting_months.first
    month1_label = I18n.l(month1, format: :month_year)

    # --- Step 1: Create a new self-attested education activity ---
    visit new_activities_flow_education_path
    verify_page(page, title: I18n.t("activities.education.new.title"))
    fill_in I18n.t("activities.education.new.school_name"), with: "University of Illinois"
    fill_in I18n.t("activities.education.new.street_address"), with: "601 E John St"
    fill_in I18n.t("activities.education.new.city"), with: "Champaign"
    fill_in I18n.t("activities.education.new.state"), with: "Illinois"
    find(".usa-combo-box__list-option", text: "Illinois (IL)").click
    fill_in I18n.t("activities.education.new.zip_code"), with: "61820"
    fill_in I18n.t("activities.education.new.contact_name"), with: "Dr. Smith"
    fill_in I18n.t("activities.education.new.contact_email"), with: "smith@illinois.edu"
    click_button I18n.t("activities.education.new.continue")

    # Hours input for each reporting month
    flow.reporting_months.each do |month|
      month_label = I18n.l(month, format: :month_year)
      verify_page(page, title: I18n.t("activities.education.hours_input.heading",
        month: month_label, organization: "University of Illinois"))
      fill_in I18n.t("activities.education.hours_input.hours_label", month: month_label), with: "4"
      click_button I18n.t("activities.education.hours_input.continue")
    end

    # Document upload
    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "University of Illinois"),
      skip_axe_rules: %w[heading-order]
    )
    attach_file I18n.t("activities.document_uploads.new.input_label"), upload_path, make_visible: true
    click_button I18n.t("activities.document_uploads.new.continue")

    # Review page
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "University of Illinois"))
    expect(page).to have_content "601 E John St, Champaign, IL"
    expect(page).to have_content "Dr. Smith"
    expect(page).to have_content "smith@illinois.edu"
    expect(page).to have_content "16"

    # --- Step 2: Save and return to the hub ---
    click_button I18n.t("activities.education.review.save")
    verify_page(page, title: I18n.t("activities.hub.in_progress_state_title"))

    # --- Step 3: Edit from the hub card → review (no back button) → edit school info → review ---
    within("[data-activity-type='education']") do
      click_link I18n.t("activities.hub.edit")
    end
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "University of Illinois"))
    expect(page).to have_button I18n.t("activities.hub.save")

    # Edit school info from review
    edit_links = all("a", text: I18n.t("activities.hub.edit"))
    edit_links.first.click
    verify_page(page, title: I18n.t("activities.education.new.edit_title"))
    fill_in I18n.t("activities.education.new.school_name"), with: "Updated University of Illinois"
    click_button I18n.t("activities.hub.save")

    # Back to review with updated data
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "Updated University of Illinois"))
    expect(page).to have_content "601 E John St, Champaign, IL"

    # Edit month 1 from review
    month_edit_links = all("table a", text: I18n.t("activities.education.review.edit"))
    month_edit_links.first.click
    verify_page(page, title: I18n.t("activities.education.hours_input.heading",
      month: month1_label, organization: "Updated University of Illinois"))
    fill_in I18n.t("activities.education.hours_input.hours_label", month: month1_label), with: "6"
    click_button I18n.t("activities.hub.save")

    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "Updated University of Illinois"))
    expect(page).to have_content "24"
    expect(page).to have_content "16"

    # --- Step 4: Save and return to the hub ---
    click_button I18n.t("activities.hub.save")

    verify_page(page, title: I18n.t("activities.hub.in_progress_state_title"))
    expect(page).to have_content("Updated University of Illinois")
  end
end
