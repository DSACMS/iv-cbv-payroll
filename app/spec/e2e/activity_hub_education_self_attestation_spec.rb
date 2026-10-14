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
    invitation = create(:activity_flow_invitation, client_agency_id: "sandbox")
    visit activities_flow_start_path(token: invitation.auth_token)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.empty_state_title"))

    flow = ActivityFlow.last

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
    fill_in I18n.t("activities.education.new.contact_title"), with: "Academic advisor"
    fill_in I18n.t("activities.education.new.contact_email"), with: "smith@illinois.edu"
    click_button I18n.t("activities.education.new.continue")

    term_title = I18n.t("activities.education.add_your_term.edit.title", school_name: "University of Illinois")
    verify_page(page, title: term_title)
    click_button I18n.t("activities.education.add_your_term.edit.continue")
    verify_page(page, title: term_title)
    expect(page).to have_text(I18n.t("activities.education.add_your_term.errors.information_heading"))

    fill_in I18n.t("activities.education.add_your_term.edit.term_start"), with: "55/2026"
    fill_in I18n.t("activities.education.add_your_term.edit.term_end"), with: flow.reporting_months.last.strftime("%m/%Y")
    select I18n.t("activities.education.add_your_term.edit.enrollment_status_options.less_than_half_time"),
      from: I18n.t("activities.education.add_your_term.edit.enrollment_status")
    fill_in I18n.t("activities.education.add_your_term.edit.credit_hours"), with: "3.5"
    click_button I18n.t("activities.education.add_your_term.edit.continue")
    verify_page(page, title: term_title)
    expect(page).to have_text(I18n.t("activities.education.add_your_term.errors.dates_heading"))
    fill_in I18n.t("activities.education.add_your_term.edit.term_start"), with: flow.reporting_months.first.strftime("%m/%Y")
    click_button I18n.t("activities.education.add_your_term.edit.continue")

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
    education_activity = EducationActivity.last
    expect(education_activity.credit_hours).to eq(3.5)

    # --- Step 2: Save and return to the hub ---
    click_button I18n.t("activities.education.review.save")
    verify_page(page, title: I18n.t("activities.hub.in_progress_state_title"))

    visit new_activities_flow_education_document_upload_path(education_id: education_activity)
    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "University of Illinois"),
      skip_axe_rules: %w[heading-order]
    )
    expect(page).to have_content(I18n.t("activities.document_uploads.heading_previous", document_count: 1))
    expect(page).to have_content("document_upload.pdf")
    expect(page.find("input[type='file']", visible: :all)).to have_xpath(
      "following::h2", text: I18n.t("activities.document_uploads.heading_previous", document_count: 1)
    )
    click_link I18n.t("activities.document_uploads.remove_file")
    expect(page).not_to have_content("document_upload.pdf")

    # --- Step 3: Edit from the hub card → review (no back button) → edit school info → review ---
    visit activities_flow_root_path
    within("[data-activity-type='education']") do
      click_link I18n.t("activities.hub.edit")
    end
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "University of Illinois"))
    expect(page).to have_button I18n.t("activities.hub.save")

    # Edit school info from review
    within(".activity-review-edit-header", text: I18n.t("activities.education.review.school_info")) do
      click_link I18n.t("activities.hub.edit")
    end
    verify_page(page, title: I18n.t("activities.education.new.edit_title"))
    expect(page).to have_field(I18n.t("activities.education.new.contact_title"), with: "Academic advisor")
    fill_in I18n.t("activities.education.new.school_name"), with: "Updated University of Illinois"
    click_button I18n.t("activities.hub.save")

    # Back to review with updated data
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "Updated University of Illinois"))
    expect(page).to have_content "601 E John St, Champaign, IL"

    # Edit the term from review
    within(".activity-review-edit-header", text: I18n.t("activities.summary.education.term_details")) do
      click_link I18n.t("activities.hub.edit")
    end
    verify_page(page, title: I18n.t("activities.education.add_your_term.edit.title", school_name: "Updated University of Illinois"))
    expect(page).to have_field(I18n.t("activities.education.add_your_term.edit.term_start"), with: flow.reporting_months.first.strftime("%m/%Y"))
    fill_in I18n.t("activities.education.add_your_term.edit.credit_hours"), with: "6"
    click_button I18n.t("activities.education.add_your_term.edit.continue")
    verify_page(page, title: I18n.t("activities.document_uploads.new.title", name: "Updated University of Illinois"), skip_axe_rules: %w[heading-order])
    click_button I18n.t("activities.hub.save")

    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "Updated University of Illinois"))
    expect(education_activity.reload.credit_hours).to eq(6)

    # --- Step 4: Save and return to the hub ---
    click_button I18n.t("activities.hub.save")

    verify_page(page, title: I18n.t("activities.hub.in_progress_state_title"))
    expect(page).to have_content("Updated University of Illinois")
  end
end
