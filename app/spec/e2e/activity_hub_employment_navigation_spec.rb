require "rails_helper"

RSpec.describe "e2e Employment self-attestation navigation", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  around do |ex|
    override_supported_providers([ :argyle ]) do
      e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      e2e.use_recording("e2e_activity_flow", &ex)
    end
  end

  let(:back_text) { I18n.t("activities.activity_header_component.back") }
  let(:exit_text) { I18n.t("activities.activity_header_component.exit") }

  def navigate_to_hub
    visit URI(root_url).request_uri
    visit activities_flow_entry_path(client_agency_id: "sandbox")
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.title"))
  end

  def start_new_employment
    within("[data-activity-type='employment']") do
      click_button I18n.t("activities.hub.add")
    end

    # Employer search page — search and click "Add employment manually"
    verify_page(page, title: I18n.t("activities.income.employer_searches.show.header"))
    find('.usa-input[type="search"]').fill_in with: "blahblahblah"
    click_button I18n.t("cbv.employer_searches.show.search")
    click_link I18n.t("activities.income.employer_searches.employer.add_employment_manually")
  end

  def fill_employer_info(employer_name: "Test Employer")
    fill_in I18n.t("activities.employment_info.employer_name"), with: employer_name
    fill_in I18n.t("activities.employment_info.street_address"), with: "123 Main St"
    fill_in I18n.t("activities.employment_info.city"), with: "Anytown"
    fill_in I18n.t("activities.employment_info.state"), with: "Florida"
    find(".usa-combo-box__list-option", text: "Florida (FL)").click
    fill_in I18n.t("activities.employment_info.zip_code"), with: "32601"
    fill_in I18n.t("activities.employment_info.contact_name"), with: "John Doe"
    fill_in I18n.t("activities.employment_info.contact_email"), with: "john@test.com"
    fill_in I18n.t("activities.employment_info.contact_phone_number"), with: "(555) 111-2222"
  end

  def fill_month_hours(month_label, income: "500", hours: "40")
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: month_label), with: income
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: month_label), with: hours
  end

  def expect_back_button(visible:)
    if visible
      expect(page).to have_css(".back-nav__link", text: back_text)
    else
      expect(page).not_to have_css(".back-nav__link")
    end
  end

  def expect_exit_button
    expect(page).to have_css(".activity-header-title__exit-link", text: exit_text)
  end

  def click_back
    find(".back-nav__link", text: back_text).click
  end

  it "back and exit buttons work correctly through creation, edit-from-review, and edit-from-hub flows" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
    navigate_to_hub

    flow = ActivityFlow.last
    month1_label = I18n.l(flow.reporting_months.first, format: :month_year)
    month2_label = I18n.l(flow.reporting_months.second, format: :month_year)

    start_new_employment

    # ===== CREATION FLOW =====

    # --- New employer info page: exit only, no back ---
    verify_page(page, title: I18n.t("activities.employment_info.title"))
    expect_exit_button
    expect_back_button(visible: false)

    fill_employer_info(employer_name: "Nav Test Employer")
    click_button I18n.t("activities.employment_info.continue")

    # --- Month 1: exit + back (back → edit info) ---
    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month1_label, organization: "Nav Test Employer"))
    expect_exit_button
    expect_back_button(visible: true)

    # Go back to edit info
    click_back
    verify_page(page, title: I18n.t("activities.employment_info.edit_title"))

    # Data should be persisted
    expect(find_field(I18n.t("activities.employment_info.employer_name")).value).to eq "Nav Test Employer"
    expect(find_field(I18n.t("activities.employment_info.street_address")).value).to eq "123 Main St"

    # Continue forward again to month 1
    click_button I18n.t("activities.employment_info.continue")
    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month1_label, organization: "Nav Test Employer"))

    fill_month_hours(month1_label, income: "500", hours: "40")
    click_button I18n.t("activities.employment.hours_input.continue")

    # --- Month 2: exit + back (back → month 1) ---
    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month2_label, organization: "Nav Test Employer"))
    expect_exit_button
    expect_back_button(visible: true)

    # Go back to month 1
    click_back
    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month1_label, organization: "Nav Test Employer"))

    # Month 1 data should be persisted
    expect(find_field(I18n.t("activities.employment.hours_input.gross_income_label", month: month1_label)).value).to eq "500"
    expect(find_field(I18n.t("activities.employment.hours_input.hours_label", month: month1_label)).value).to eq "40"

    # Continue forward to month 2 again
    click_button I18n.t("activities.employment.hours_input.continue")
    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month2_label, organization: "Nav Test Employer"))

    fill_month_hours(month2_label, income: "300", hours: "20")
    click_button I18n.t("activities.employment.hours_input.continue")

    # --- Review page: exit + back (back → last month) ---
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Nav Test Employer"))
    expect_exit_button
    expect_back_button(visible: true)

    # Go back to month 2
    click_back
    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month2_label, organization: "Nav Test Employer"))

    # Month 2 data should be persisted
    expect(find_field(I18n.t("activities.employment.hours_input.gross_income_label", month: month2_label)).value).to eq "300"
    expect(find_field(I18n.t("activities.employment.hours_input.hours_label", month: month2_label)).value).to eq "20"

    # Go forward to review
    click_button I18n.t("activities.employment.hours_input.continue")
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Nav Test Employer"))

    # ===== EDIT FROM REVIEW (still in creation flow) =====

    # --- Edit employer info from review (back should go to review) ---
    edit_links = all("a", text: I18n.t("activities.hub.edit"))
    edit_links.first.click

    verify_page(page, title: I18n.t("activities.employment_info.edit_title"))
    expect_back_button(visible: true)

    # Click back — should return to review
    click_back
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Nav Test Employer"))

    # --- Edit employer info and save — should return to review ---
    edit_links = all("a", text: I18n.t("activities.hub.edit"))
    edit_links.first.click
    verify_page(page, title: I18n.t("activities.employment_info.edit_title"))
    fill_in I18n.t("activities.employment_info.employer_name"), with: "Updated Employer"
    click_button I18n.t("activities.hub.save")

    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))

    # --- Edit month from review (back should go to review) ---
    month_edit_links = all(".subheader-row a", text: I18n.t("activities.community_service.review.edit"))
    month_edit_links.first.click

    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month1_label, organization: "Updated Employer"))
    expect_back_button(visible: true)

    # Click back — should return to review, not month 2
    click_back
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))

    # --- Edit month and save — should return to review ---
    month_edit_links = all(".subheader-row a", text: I18n.t("activities.community_service.review.edit"))
    month_edit_links.first.click
    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month1_label, organization: "Updated Employer"))
    fill_month_hours(month1_label, income: "1100", hours: "85")
    click_button I18n.t("activities.hub.save")

    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))
    expect(page).to have_content "$1,100"
    expect(page).to have_content "85"

    # Save to hub
    click_button I18n.t("activities.employment.review.save")
    verify_page(page, title: I18n.t("activities.hub.title"))

    # ===== EDIT FROM HUB =====

    within("[data-activity-type='employment']") do
      click_link I18n.t("activities.hub.edit")
    end

    # Should land on review page with NO back button (from_edit flow)
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))
    expect_exit_button
    expect_back_button(visible: false)

    # Submit button should say "Save changes" in edit flow
    expect(page).to have_button I18n.t("activities.hub.save")

    # --- Edit employer info from review in edit flow ---
    edit_links = all("a", text: I18n.t("activities.hub.edit"))
    edit_links.first.click

    verify_page(page, title: I18n.t("activities.employment_info.edit_title"))
    expect_back_button(visible: true)

    # Back should go to review
    click_back
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))
    # Review should still have no back button
    expect_back_button(visible: false)

    # --- Edit month from review in edit flow ---
    month_edit_links = all(".subheader-row a", text: I18n.t("activities.community_service.review.edit"))
    month_edit_links.first.click

    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month1_label, organization: "Updated Employer"))
    expect_back_button(visible: true)

    # Back should go to review
    click_back
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))
    # Review should still have no back button after returning
    expect_back_button(visible: false)

    # --- Edit month, save, verify review still has no back ---
    month_edit_links = all(".subheader-row a", text: I18n.t("activities.community_service.review.edit"))
    month_edit_links.last.click

    verify_page(page, title: I18n.t("activities.employment.hours_input.heading",
      month: month2_label, organization: "Updated Employer"))
    fill_month_hours(month2_label, income: "1900", hours: "145")
    click_button I18n.t("activities.hub.save")

    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Updated Employer"))
    expect_back_button(visible: false)
    expect(page).to have_content "$1,900"
    expect(page).to have_content "145"

    # Save changes back to hub
    click_button I18n.t("activities.hub.save")
    verify_page(page, title: I18n.t("activities.hub.title"))
  end
end
