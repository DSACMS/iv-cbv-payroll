require "rails_helper"

RSpec.describe "e2e Education self-attestation back/exit navigation", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  around do |ex|
    override_supported_providers([ :argyle ]) do
      e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      e2e.use_recording("e2e_activity_flow", &ex)
    end
  end

  it "supports back and exit navigation through the full education self-attestation flow" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
    upload_path = Rails.root.join("spec/fixtures/files/document_upload.pdf")
    back_text = I18n.t("activities.activity_header_component.back")

    # Start at the activity hub
    visit URI(root_url).request_uri
    visit activities_flow_entry_path(client_agency_id: "sandbox")
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.title"))

    flow = ActivityFlow.last
    month1 = flow.reporting_months.first
    month2 = flow.reporting_months.second
    month1_label = I18n.l(month1, format: :month_year)
    month2_label = I18n.l(month2, format: :month_year)

    # =====================================================================
    # Phase 1: Creation flow — back button from every page
    # =====================================================================

    # --- New school info page (no back button) ---
    visit new_activities_flow_education_path
    verify_page(page, title: I18n.t("activities.education.new.title"))
    expect(page).not_to have_css(".back-nav__link")

    fill_in I18n.t("activities.education.new.school_name"), with: "University of Illinois"
    fill_in I18n.t("activities.education.new.street_address"), with: "601 E John St"
    fill_in I18n.t("activities.education.new.city"), with: "Champaign"
    fill_in I18n.t("activities.education.new.state"), with: "Illinois"
    find(".usa-combo-box__list-option", text: "Illinois (IL)").click
    fill_in I18n.t("activities.education.new.zip_code"), with: "61820"
    fill_in I18n.t("activities.education.new.contact_name"), with: "Dr. Smith"
    fill_in I18n.t("activities.education.new.contact_email"), with: "smith@illinois.edu"
    fill_in I18n.t("activities.education.new.contact_phone_number"), with: "(217) 333-1000"
    click_button I18n.t("activities.education.new.continue")

    # --- Month 0: back → school info edit, data preserved ---
    verify_page(page, title: I18n.t("activities.education.hours_input.heading",
      month: month1_label, organization: "University of Illinois"))
    expect(page).to have_css(".back-nav__link")

    # Click back to school info and verify data is preserved
    find(".back-nav__link").click
    verify_page(page, title: I18n.t("activities.education.new.edit_title"))
    expect(find_field(I18n.t("activities.education.new.school_name")).value).to eq "University of Illinois"
    expect(find_field(I18n.t("activities.education.new.street_address")).value).to eq "601 E John St"
    expect(find_field(I18n.t("activities.education.new.city")).value).to eq "Champaign"
    expect(find_field(I18n.t("activities.education.new.zip_code")).value).to eq "61820"
    expect(find_field(I18n.t("activities.education.new.contact_name")).value).to eq "Dr. Smith"
    expect(find_field(I18n.t("activities.education.new.contact_email")).value).to eq "smith@illinois.edu"
    expect(find_field(I18n.t("activities.education.new.contact_phone_number")).value).to eq "(217) 333-1000"

    # No back button on edit page when not from_review
    expect(page).not_to have_css(".back-nav__link")

    # Continue back to month 0
    click_button I18n.t("activities.education.new.continue")
    verify_page(page, title: I18n.t("activities.education.hours_input.heading",
      month: month1_label, organization: "University of Illinois"))

    # Fill month 0 and continue
    fill_in I18n.t("activities.education.hours_input.hours_label", month: month1_label), with: "4"
    click_button I18n.t("activities.education.hours_input.continue")

    # --- Month 1: back → month 0, data preserved ---
    verify_page(page, title: I18n.t("activities.education.hours_input.heading",
      month: month2_label, organization: "University of Illinois"))
    expect(page).to have_css(".back-nav__link")

    find(".back-nav__link").click
    verify_page(page, title: I18n.t("activities.education.hours_input.heading",
      month: month1_label, organization: "University of Illinois"))
    expect(find_field(I18n.t("activities.education.hours_input.hours_label", month: month1_label)).value).to eq "4"

    # Continue through month 0 again
    click_button I18n.t("activities.education.hours_input.continue")
    verify_page(page, title: I18n.t("activities.education.hours_input.heading",
      month: month2_label, organization: "University of Illinois"))

    # Fill month 1 and continue
    fill_in I18n.t("activities.education.hours_input.hours_label", month: month2_label), with: "6"
    click_button I18n.t("activities.education.hours_input.continue")

    # --- Document uploads: back → month 1, data preserved ---
    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "University of Illinois"),
      skip_axe_rules: %w[heading-order]
    )
    expect(page).to have_css(".back-nav__link")

    find(".back-nav__link").click
    verify_page(page, title: I18n.t("activities.education.hours_input.heading",
      month: month2_label, organization: "University of Illinois"))
    expect(find_field(I18n.t("activities.education.hours_input.hours_label", month: month2_label)).value).to eq "6"

    # Continue through month 1 to doc uploads again
    click_button I18n.t("activities.education.hours_input.continue")
    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "University of Illinois"),
      skip_axe_rules: %w[heading-order]
    )

    # Skip uploads and continue to review
    click_button I18n.t("activities.document_uploads.new.continue")

    # --- Review: back → document uploads ---
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "University of Illinois"))
    expect(page).to have_css(".back-nav__link")
    expect(page).to have_content "601 E John St, Champaign, IL"
    expect(page).to have_content "Dr. Smith"
    expect(page).to have_content "smith@illinois.edu"

    find(".back-nav__link").click
    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "University of Illinois"),
      skip_axe_rules: %w[heading-order]
    )

    # Continue back to review
    click_button I18n.t("activities.document_uploads.new.continue")
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "University of Illinois"))

    # =====================================================================
    # Phase 2: Edit from review — school info
    # =====================================================================

    # Click Edit next to school info heading
    edit_links = all("a", text: I18n.t("activities.hub.edit"))
    edit_links.first.click

    verify_page(page, title: I18n.t("activities.education.new.edit_title"))
    # Should have back button pointing to review
    expect(page).to have_css(".back-nav__link")
    # Button should say "Save changes" (not "Continue")
    expect(page).to have_button I18n.t("activities.hub.save")

    # Verify data is pre-populated
    expect(find_field(I18n.t("activities.education.new.school_name")).value).to eq "University of Illinois"

    # Click back → should return to review
    find(".back-nav__link").click
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "University of Illinois"))

    # Edit again, this time actually change data and save
    edit_links = all("a", text: I18n.t("activities.hub.edit"))
    edit_links.first.click
    verify_page(page, title: I18n.t("activities.education.new.edit_title"))

    fill_in I18n.t("activities.education.new.school_name"), with: "Updated University"
    fill_in I18n.t("activities.education.new.street_address"), with: "123 New Street"
    click_button I18n.t("activities.hub.save")

    # Should return directly to review (not month 0) with updated data
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "Updated University"))
    expect(page).to have_content "123 New Street"

    # =====================================================================
    # Phase 3: Edit from review — months
    # =====================================================================

    # Click Edit on month 1
    month_edit_links = all(".subheader-row a", text: I18n.t("activities.education.review.edit"))
    month_edit_links.first.click

    verify_page(page, title: I18n.t("activities.education.hours_input.heading",
      month: month1_label, organization: "Updated University"))
    # Should have back button pointing to review
    expect(page).to have_css(".back-nav__link")
    # Button should say "Save changes"
    expect(page).to have_button I18n.t("activities.hub.save")
    # Data preserved
    expect(find_field(I18n.t("activities.education.hours_input.hours_label", month: month1_label)).value).to eq "4"

    # Click back → should return to review (not to school info edit)
    find(".back-nav__link").click
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "Updated University"))

    # Edit month again, change data, save
    month_edit_links = all(".subheader-row a", text: I18n.t("activities.education.review.edit"))
    month_edit_links.first.click
    verify_page(page, title: I18n.t("activities.education.hours_input.heading",
      month: month1_label, organization: "Updated University"))

    fill_in I18n.t("activities.education.hours_input.hours_label", month: month1_label), with: "8"
    click_button I18n.t("activities.hub.save")

    # Should go directly back to review (not month 1)
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "Updated University"))

    # =====================================================================
    # Phase 4: Save to hub
    # =====================================================================

    click_button I18n.t("activities.education.review.save")
    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_content "Updated University"

    # =====================================================================
    # Phase 5: Edit from hub — review has no back button
    # =====================================================================

    within("[data-activity-type='education']") do
      click_link I18n.t("activities.hub.edit")
    end

    # Hub edit starts on month 1 input, then continues through flow back to review.
    verify_page(page, title: I18n.t("activities.education.hours_input.heading",
      month: month1_label, organization: "Updated University"))
    expect(page).to have_button I18n.t("activities.education.hours_input.continue")
    click_button I18n.t("activities.education.hours_input.continue")

    verify_page(page, title: I18n.t("activities.education.hours_input.heading",
      month: month2_label, organization: "Updated University"))
    click_button I18n.t("activities.education.hours_input.continue")

    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "Updated University"),
      skip_axe_rules: %w[heading-order]
    )
    click_button I18n.t("activities.document_uploads.new.continue")

    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "Updated University"))
    expect(page).not_to have_css(".back-nav__link")
    expect(page).to have_button I18n.t("activities.hub.save")

    # Edit school info from review in edit-from-hub flow
    edit_links = all("a", text: I18n.t("activities.hub.edit"))
    edit_links.first.click
    verify_page(page, title: I18n.t("activities.education.new.edit_title"))
    # Back button should go to review
    expect(page).to have_css(".back-nav__link")
    expect(page).to have_button I18n.t("activities.hub.save")

    # Click back → review (still no back button on review since from_edit persists)
    find(".back-nav__link").click
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "Updated University"))
    expect(page).not_to have_css(".back-nav__link")

    # Edit a month from review in edit-from-hub flow
    month_edit_links = all(".subheader-row a", text: I18n.t("activities.education.review.edit"))
    month_edit_links.last.click
    verify_page(page, title: I18n.t("activities.education.hours_input.heading",
      month: month2_label, organization: "Updated University"))
    expect(page).to have_css(".back-nav__link")
    expect(page).to have_button I18n.t("activities.hub.save")

    # Back → review
    find(".back-nav__link").click
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "Updated University"))
    expect(page).not_to have_css(".back-nav__link")

    # Save changes → hub
    click_button I18n.t("activities.hub.save")
    verify_page(page, title: I18n.t("activities.hub.title"))
  end
end
