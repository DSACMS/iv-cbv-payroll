require "rails_helper"

RSpec.describe "e2e Employment self-attestation review flow", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  around do |ex|
    override_supported_providers([ :argyle ]) do
      e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      e2e.use_recording("e2e_activity_flow", &ex)
    end
  end

  it "supports editing an employment activity through the full flow" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
    visit URI(root_url).request_uri
    visit activities_flow_entry_path(client_agency_id: "sandbox")
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.title"))

    flow = ActivityFlow.last
    month1 = flow.reporting_months.first
    month2 = flow.reporting_months.second
    month1_label = I18n.l(month1, format: :month_year)
    month2_label = I18n.l(month2, format: :month_year)

    # --- Step 1: Create a new employment activity ---
    within("[data-activity-type='employment']") do
      click_button I18n.t("activities.hub.add")
    end

    # Employer search page — search and click "Add employment manually"
    verify_page(page, title: I18n.t("activities.income.employer_searches.show.header"))
    find('.usa-input[type="search"]').fill_in with: "blahblahblah"
    click_button I18n.t("activities.income.employer_searches.show.search")
    click_link I18n.t("activities.income.employer_searches.employer.add_employment_manually")

    verify_page(page, title: I18n.t("activities.employment_info.title"))
    fill_in I18n.t("activities.employment_info.employer_name"), with: "Gainesville Wrecking"
    fill_in I18n.t("activities.employment_info.street_address"), with: "942 W Harlan Ave"
    fill_in I18n.t("activities.employment_info.city"), with: "Gainesville"
    fill_in I18n.t("activities.employment_info.state"), with: "Florida"
    find(".usa-combo-box__list-option", text: "Florida (FL)").click
    fill_in I18n.t("activities.employment_info.zip_code"), with: "32611"
    fill_in I18n.t("activities.employment_info.contact_name"), with: "Donny Spears"
    fill_in I18n.t("activities.employment_info.contact_email"), with: "donny@gainesvillewrecking.com"
    fill_in I18n.t("activities.employment_info.contact_phone_number"), with: "(415) 344-8009"
    click_button I18n.t("activities.employment_info.continue")

    # Hours input month 1
    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month1_label, organization: "Gainesville Wrecking"))
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: month1_label), with: "500"
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: month1_label), with: "40"
    click_button I18n.t("activities.employment.hours_input.continue")

    # Hours input month 2
    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month2_label, organization: "Gainesville Wrecking"))
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: month2_label), with: "300"
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: month2_label), with: "20"
    click_button I18n.t("activities.employment.hours_input.continue")

    # Document upload page
    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "Gainesville Wrecking"),
      skip_axe_rules: %w[heading-order]
    )
    click_button I18n.t("activities.document_uploads.new.continue")

    # Review page
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Gainesville Wrecking"))
    expect(page).to have_content "Gainesville Wrecking"
    expect(page).to have_content "942 W Harlan Ave"
    expect(page).to have_content "Donny Spears"
    expect(page).to have_content "donny@gainesvillewrecking.com"
    expect(page).to have_content "$500"
    expect(page).to have_content "40"
    expect(page).to have_content "$300"
    expect(page).to have_content "20"

    # --- Step 2: Edit all employer info fields from the review page ---
    # The review page has multiple "Edit" links; target the one next to the employer info heading
    edit_links = all("a", text: I18n.t("activities.hub.edit"))
    edit_links.first.click

    verify_page(page, title: I18n.t("activities.employment_info.edit_title"))

    # Verify all fields are pre-populated with previously entered values
    expect(find_field(I18n.t("activities.employment_info.employer_name")).value).to eq "Gainesville Wrecking"
    expect(find_field(I18n.t("activities.employment_info.street_address")).value).to eq "942 W Harlan Ave"
    expect(find_field(I18n.t("activities.employment_info.city")).value).to eq "Gainesville"
    expect(find_field(I18n.t("activities.employment_info.zip_code")).value).to eq "32611"
    expect(find_field(I18n.t("activities.employment_info.contact_name")).value).to eq "Donny Spears"
    expect(find_field(I18n.t("activities.employment_info.contact_email")).value).to eq "donny@gainesvillewrecking.com"
    expect(find_field(I18n.t("activities.employment_info.contact_phone_number")).value).to eq "(415) 344-8009"

    fill_in I18n.t("activities.employment_info.employer_name"), with: "Updated Employer"
    fill_in I18n.t("activities.employment_info.street_address"), with: "123 New Street"
    fill_in I18n.t("activities.employment_info.city"), with: "Tampa"
    fill_in I18n.t("activities.employment_info.state"), with: "Texas"
    find(".usa-combo-box__list-option", text: "Texas (TX)").click
    fill_in I18n.t("activities.employment_info.zip_code"), with: "75001"
    fill_in I18n.t("activities.employment_info.contact_name"), with: "Jane Smith"
    fill_in I18n.t("activities.employment_info.contact_email"), with: "jane@updatedemployer.com"
    fill_in I18n.t("activities.employment_info.contact_phone_number"), with: "(555) 123-4567"
    click_button I18n.t("activities.hub.save")

    # Review page (creation flow — button should say "Save and add to my report")
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))
    expect(page).to have_button I18n.t("activities.employment.review.save")
    expect(page).to have_content "123 New Street"
    expect(page).to have_content "Jane Smith"
    expect(page).to have_content "jane@updatedemployer.com"
    expect(page).to have_content "(555) 123-4567"

    # --- Step 3: Edit a single month from the review page ---
    # Month edit links are inside .subheader-row; the employer edit link is outside the table
    month_edit_links = all("td a", text: I18n.t("activities.community_service.review.edit"))
    month_edit_links.first.click

    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month1_label, organization: "Updated Employer"))
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: month1_label), with: "600"
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: month1_label), with: "45"
    click_button I18n.t("activities.hub.save")

    # Should go directly back to review, NOT to month 2
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))
    expect(page).to have_content "$600"
    expect(page).to have_content "45"

    # --- Step 4: Validation guard — cannot zero out all months from review ---
    # Set month 2 to 0 via edit from review
    month_edit_links = all("td a", text: I18n.t("activities.community_service.review.edit"))
    month_edit_links.last.click

    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month2_label, organization: "Updated Employer"))
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: month2_label), with: "0"
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: month2_label), with: "0"
    click_button I18n.t("activities.hub.save")

    # Should succeed — month 1 still has valid values
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))

    # Now try to set month 1 to 0 — should fail validation
    month_edit_links = all("td a", text: I18n.t("activities.community_service.review.edit"))
    month_edit_links.first.click

    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month1_label, organization: "Updated Employer"))
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: month1_label), with: "0"
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: month1_label), with: "0"
    click_button I18n.t("activities.hub.save")

    # Should stay on hours input with an error
    expect(page).to have_content I18n.t("activities.employment.hours_input.error_heading")

    # Fix it — set to valid values and save
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: month1_label), with: "200"
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: month1_label), with: "10"
    click_button I18n.t("activities.hub.save")

    # Back to review, then save to hub
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))
    click_button I18n.t("activities.employment.review.save")

    verify_page(page, title: I18n.t("activities.hub.title"))
  end
end
