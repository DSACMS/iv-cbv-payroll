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
    invitation = create(:activity_flow_invitation, client_agency_id: "sandbox")
    visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 3)
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.empty_state_title"))

    flow = ActivityFlow.last
    first_selected_month = flow.reporting_months.first
    unselected_month = flow.reporting_months.second
    second_selected_month = flow.reporting_months.third
    first_selected_month_label = I18n.l(first_selected_month, format: :month_year)
    unselected_month_label = I18n.l(unselected_month, format: :month_year)
    second_selected_month_label = I18n.l(second_selected_month, format: :month_year)
    first_selected_month_name = I18n.l(first_selected_month, format: :month)
    second_selected_month_name = I18n.l(second_selected_month, format: :month)

    # --- Step 1: Create a new employment activity ---
    within("[data-activity-type='employment']") do
      click_button I18n.t("activities.hub.add")
    end

    # Add your work page
    verify_page(page, title: I18n.t("activities.employment.add_your_work.show.header"))
    click_button I18n.t("continue")
    expect(page).to have_content(I18n.t("shared.next_path.notice_no_answer"))
    find("label[for='add_work_method_connect_automatically']").click
    click_button I18n.t("continue")

    # Employer search page
    verify_page(page, title: I18n.t("activities.income.employer_searches.show.header"))
    find('.usa-input[type="search"]').fill_in with: "blahblahblah"
    click_button I18n.t("activities.income.employer_searches.show.search")
    verify_page(page, title: I18n.t("activities.income.employer_searches.show.search_results_header"))
    expect(page).to have_content(I18n.t("activities.income.employer_searches.employer.search_subheader"))
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

    # Month selection
    month_selection_title = I18n.t(
      "activities.employment.month_selections.edit.title",
      employer_name: "Gainesville Wrecking"
    )
    verify_page(page, title: month_selection_title)
    expect(page).to have_content(flow.reporting_window_display)
    click_button I18n.t("activities.employment.month_selections.edit.continue")
    expect(page).to have_content(I18n.t("activities.employment.month_selections.edit.error_heading"))

    [ first_selected_month_label, second_selected_month_label ].each do |month_label|
      find("label", text: month_label, exact_text: true).click
    end
    click_button I18n.t("activities.employment.month_selections.edit.continue")

    # Hours input for the first selected month
    monthly_details_title = I18n.t(
      "activities.employment.hours_input.heading",
      organization: "Gainesville Wrecking"
    )
    verify_page(page, title: monthly_details_title)
    expect(page).to have_content(
      [
        I18n.t(
          "activities.employment.hours_input.month_indicator",
          current: 1,
          total: 2
        ),
        first_selected_month_name
      ].join(" "),
      normalize_ws: true
    )
    expect(page).to have_no_selector('input[name="no_hours"]', visible: :all)

    click_link I18n.t("activities.activity_header_component.back")
    verify_page(page, title: month_selection_title)
    [ first_selected_month_label, second_selected_month_label ].each do |month_label|
      expect(page).to have_field(month_label, checked: true, visible: :all)
    end
    expect(page).to have_field(unselected_month_label, checked: false, visible: :all)
    click_button I18n.t("activities.employment.month_selections.edit.continue")

    verify_page(page, title: monthly_details_title)
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: first_selected_month_name), with: "500"
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: first_selected_month_name), with: "40"
    click_button I18n.t("activities.employment.hours_input.continue")

    # Hours input for the second selected month
    verify_page(page, title: monthly_details_title)
    expect(page).to have_content(
      [
        I18n.t(
          "activities.employment.hours_input.month_indicator",
          current: 2,
          total: 2
        ),
        second_selected_month_name
      ].join(" "),
      normalize_ws: true
    )
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: second_selected_month_name), with: "300"
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: second_selected_month_name), with: "20"
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
    expect(page).to have_no_content unselected_month_label

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
    # Month edit links are inside the table; the employer edit link is outside the table
    month_edit_links = all("table a", text: I18n.t("activities.community_service.review.edit"))
    month_edit_links.first.click

    updated_monthly_details_title = I18n.t(
      "activities.employment.hours_input.heading",
      organization: "Updated Employer"
    )
    verify_page(page, title: updated_monthly_details_title)
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: first_selected_month_name), with: "600"
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: first_selected_month_name), with: "45"
    click_button I18n.t("activities.hub.save")

    # Should go directly back to review, not to the next selected month
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))
    expect(page).to have_content "$600"
    expect(page).to have_content "45"

    # --- Step 4: Each selected month requires income or hours ---
    # Enter only income for the second selected month
    month_edit_links = all("table a", text: I18n.t("activities.community_service.review.edit"))
    month_edit_links.last.click

    verify_page(page, title: updated_monthly_details_title)
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: second_selected_month_name), with: "300"
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: second_selected_month_name), with: ""
    click_button I18n.t("activities.hub.save")

    # Should succeed because one field was filled in
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))

    # Clear both fields for the first selected month
    month_edit_links = all("table a", text: I18n.t("activities.community_service.review.edit"))
    month_edit_links.first.click

    verify_page(page, title: updated_monthly_details_title)
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: first_selected_month_name), with: ""
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: first_selected_month_name), with: ""
    click_button I18n.t("activities.hub.save")

    # Should stay on hours input with an error
    expect(page).to have_content I18n.t("activities.employment.hours_input.error_heading")
    expect(page).to have_content I18n.t("activities.employment.hours_input.error_body")
    expect(page).to have_no_selector(".usa-error-message")

    # Fix it — set to valid values and save
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: first_selected_month_name), with: "200"
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: first_selected_month_name), with: "10"
    click_button I18n.t("activities.hub.save")

    # Back to review, then save to hub
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))
    click_button I18n.t("activities.employment.review.save")

    verify_page(page, title: I18n.t("activities.hub.in_progress_state_title"))
  end
end
