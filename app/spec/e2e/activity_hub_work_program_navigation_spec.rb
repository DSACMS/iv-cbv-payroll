require "rails_helper"

RSpec.describe "e2e Work Program self-attestation navigation", :js, type: :feature do
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

  def fill_program_info(program_name: "Test Program", org_name: "Test Org")
    fill_in I18n.t("activities.job_training.form.organization_name"), with: org_name
    fill_in I18n.t("activities.job_training.form.program_name"), with: program_name
    fill_in I18n.t("activities.job_training.form.street_address"), with: "123 Main St"
    fill_in I18n.t("activities.job_training.form.city"), with: "Baton Rouge"
    fill_in I18n.t("activities.job_training.form.state"), with: "Louisiana"
    find(".usa-combo-box__list-option", text: "Louisiana (LA)").click
    fill_in I18n.t("activities.job_training.form.zip_code"), with: "70801"
    fill_in I18n.t("activities.job_training.form.contact_name"), with: "Jane Trainer"
    fill_in I18n.t("activities.job_training.form.contact_email"), with: "jane@example.com"
  end

  def fill_month_hours(month_label, hours:)
    fill_in I18n.t("activities.work_programs.hours_input.hours_label", month: month_label), with: hours
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

    within("[data-activity-type='work_programs']") do
      click_button I18n.t("activities.hub.add")
    end

    # ===== CREATION FLOW =====

    # --- New program info page: exit only, no back ---
    verify_page(page, title: I18n.t("activities.job_training.new.title"))
    expect_exit_button
    expect_back_button(visible: false)

    fill_program_info(program_name: "Nav Test Program", org_name: "Nav Test Org")
    click_button I18n.t("activities.job_training.form.continue")

    # --- Month 1: exit + back (back → edit info) ---
    verify_page(page, title: I18n.t("activities.work_programs.hours_input.heading",
      month: month1_label, organization: "Nav Test Program"))
    expect_exit_button
    expect_back_button(visible: true)

    # Go back to edit info
    click_back
    verify_page(page, title: I18n.t("activities.job_training.edit_title"))

    # Data should be persisted
    expect(find_field(I18n.t("activities.job_training.form.program_name")).value).to eq "Nav Test Program"
    expect(find_field(I18n.t("activities.job_training.form.street_address")).value).to eq "123 Main St"

    # Continue forward again to month 1
    click_button I18n.t("activities.job_training.form.continue")
    verify_page(page, title: I18n.t("activities.work_programs.hours_input.heading",
      month: month1_label, organization: "Nav Test Program"))

    fill_month_hours(month1_label, hours: "20")
    click_button I18n.t("activities.work_programs.hours_input.continue")

    # --- Month 2: exit + back (back → month 1) ---
    verify_page(page, title: I18n.t("activities.work_programs.hours_input.heading",
      month: month2_label, organization: "Nav Test Program"))
    expect_exit_button
    expect_back_button(visible: true)

    # Go back to month 1
    click_back
    verify_page(page, title: I18n.t("activities.work_programs.hours_input.heading",
      month: month1_label, organization: "Nav Test Program"))

    # Month 1 data should be persisted
    expect(find_field(I18n.t("activities.work_programs.hours_input.hours_label", month: month1_label)).value).to eq "20"

    # Continue forward to month 2 again
    click_button I18n.t("activities.work_programs.hours_input.continue")
    verify_page(page, title: I18n.t("activities.work_programs.hours_input.heading",
      month: month2_label, organization: "Nav Test Program"))

    fill_month_hours(month2_label, hours: "10")
    click_button I18n.t("activities.work_programs.hours_input.continue")

    # --- Document uploads: exit + back (back → month 2) ---
    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "Nav Test Program"),
      skip_axe_rules: %w[heading-order]
    )
    expect_exit_button
    expect_back_button(visible: true)

    # Go back to month 2
    click_back
    verify_page(page, title: I18n.t("activities.work_programs.hours_input.heading",
      month: month2_label, organization: "Nav Test Program"))

    # Month 2 data should be persisted
    expect(find_field(I18n.t("activities.work_programs.hours_input.hours_label", month: month2_label)).value).to eq "10"

    # Continue through month 2 to doc uploads again
    click_button I18n.t("activities.work_programs.hours_input.continue")
    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "Nav Test Program"),
      skip_axe_rules: %w[heading-order]
    )

    # Skip uploads and continue to review
    click_button I18n.t("activities.document_uploads.new.continue")

    # --- Review page: exit + back (back → doc uploads) ---
    verify_page(page, title: I18n.t("activities.work_programs.review.title", program_name: "Nav Test Program"))
    expect_exit_button
    expect_back_button(visible: true)

    # Go back to doc uploads
    click_back
    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "Nav Test Program"),
      skip_axe_rules: %w[heading-order]
    )

    # Continue back to review
    click_button I18n.t("activities.document_uploads.new.continue")
    verify_page(page, title: I18n.t("activities.work_programs.review.title", program_name: "Nav Test Program"))

    # ===== EDIT FROM REVIEW (still in creation flow) =====

    # --- Edit program info from review (back should go to review) ---
    edit_links = all("a", text: I18n.t("activities.hub.edit"))
    edit_links.first.click

    verify_page(page, title: I18n.t("activities.job_training.edit_title"))
    expect_back_button(visible: true)
    expect(page).to have_button I18n.t("activities.hub.save")

    # Click back — should return to review
    click_back
    verify_page(page, title: I18n.t("activities.work_programs.review.title", program_name: "Nav Test Program"))

    # --- Edit program info and save — should return to review ---
    edit_links = all("a", text: I18n.t("activities.hub.edit"))
    edit_links.first.click
    verify_page(page, title: I18n.t("activities.job_training.edit_title"))
    fill_in I18n.t("activities.job_training.form.program_name"), with: "Updated Program"
    click_button I18n.t("activities.hub.save")

    verify_page(page, title: I18n.t("activities.work_programs.review.title", program_name: "Updated Program"))

    # --- Edit month from review (back should go to review) ---
    month_edit_links = all(".subheader-row a", text: I18n.t("activities.work_programs.review.edit"))
    month_edit_links.first.click

    verify_page(page, title: I18n.t("activities.work_programs.hours_input.heading",
      month: month1_label, organization: "Updated Program"))
    expect_back_button(visible: true)
    expect(page).to have_button I18n.t("activities.hub.save")

    # Click back — should return to review, not month 2
    click_back
    verify_page(page, title: I18n.t("activities.work_programs.review.title", program_name: "Updated Program"))

    # --- Edit month and save — should return to review ---
    month_edit_links = all(".subheader-row a", text: I18n.t("activities.work_programs.review.edit"))
    month_edit_links.first.click
    verify_page(page, title: I18n.t("activities.work_programs.hours_input.heading",
      month: month1_label, organization: "Updated Program"))
    fill_month_hours(month1_label, hours: "30")
    click_button I18n.t("activities.hub.save")

    verify_page(page, title: I18n.t("activities.work_programs.review.title", program_name: "Updated Program"))
    expect(page).to have_content "30"

    # Save to hub
    click_button I18n.t("activities.work_programs.review.save")
    verify_page(page, title: I18n.t("activities.hub.title"))

    # ===== EDIT FROM HUB =====

    within("[data-activity-type='work_programs']") do
      click_link I18n.t("activities.hub.edit")
    end

    # Should land on review page with NO back button (from_edit flow)
    verify_page(page, title: I18n.t("activities.work_programs.review.title", program_name: "Updated Program"))
    expect_exit_button
    expect_back_button(visible: false)

    # Submit button should say "Save changes" in edit flow
    expect(page).to have_button I18n.t("activities.hub.save")

    # --- Edit program info from review in edit flow ---
    edit_links = all("a", text: I18n.t("activities.hub.edit"))
    edit_links.first.click

    verify_page(page, title: I18n.t("activities.job_training.edit_title"))
    expect_back_button(visible: true)

    # Back should go to review
    click_back
    verify_page(page, title: I18n.t("activities.work_programs.review.title", program_name: "Updated Program"))
    # Review should still have no back button
    expect_back_button(visible: false)

    # --- Edit month from review in edit flow ---
    month_edit_links = all(".subheader-row a", text: I18n.t("activities.work_programs.review.edit"))
    month_edit_links.first.click

    verify_page(page, title: I18n.t("activities.work_programs.hours_input.heading",
      month: month1_label, organization: "Updated Program"))
    expect_back_button(visible: true)

    # Back should go to review
    click_back
    verify_page(page, title: I18n.t("activities.work_programs.review.title", program_name: "Updated Program"))
    # Review should still have no back button after returning
    expect_back_button(visible: false)

    # --- Edit month, save, verify review still has no back ---
    month_edit_links = all(".subheader-row a", text: I18n.t("activities.work_programs.review.edit"))
    month_edit_links.last.click

    verify_page(page, title: I18n.t("activities.work_programs.hours_input.heading",
      month: month2_label, organization: "Updated Program"))
    fill_month_hours(month2_label, hours: "15")
    click_button I18n.t("activities.hub.save")

    verify_page(page, title: I18n.t("activities.work_programs.review.title", program_name: "Updated Program"))
    expect_back_button(visible: false)
    expect(page).to have_content "15"

    # Save changes back to hub
    click_button I18n.t("activities.hub.save")
    verify_page(page, title: I18n.t("activities.hub.title"))
  end
end
