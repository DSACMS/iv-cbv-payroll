require "rails_helper"

RSpec.describe 'e2e Activity Hub flow test', :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  around do |ex|
    override_supported_providers([ :argyle ]) do
      @e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      @e2e.use_recording("e2e_activity_flow", &ex)
    end
  end

  it "completes the generic flow for all self-attestation activities" do
    upload_path = Rails.root.join("spec/fixtures/files/document_upload.pdf")

    visit URI(root_url).request_uri

    visit activities_flow_entry_path(client_agency_id: "sandbox") # This would normally be inferred
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    click_link I18n.t("activities.entries.show.continue")

    verify_page(page, title: I18n.t("activities.hub.title"))
    flow = ActivityFlow.last

    # Add a Community Service activity
    within("[data-activity-type='community_service']") do
      click_button I18n.t("activities.hub.add")
    end
    verify_page(page, title: I18n.t("activities.community_service.new_title"))
    fill_in I18n.t("activities.community_service.organization_name"), with: "Helping Hands"
    fill_in I18n.t("activities.community_service.street_address"), with: "123 Main St"
    fill_in I18n.t("activities.community_service.city"), with: "Springfield"
    select "Illinois", from: I18n.t("activities.community_service.state")
    fill_in I18n.t("activities.community_service.zip_code"), with: "62701"
    fill_in I18n.t("activities.community_service.coordinator_name"), with: "Jane Doe"
    fill_in I18n.t("activities.community_service.coordinator_email"), with: "jane@example.com"
    click_button I18n.t("activities.community_service.continue")

    verify_page(page, title: I18n.t("activities.community_service.hours_input.heading",
      month: I18n.l(flow.reporting_months.first, format: :month_year),
      organization: "Helping Hands"))
    fill_in I18n.t("activities.community_service.hours_input.hours_label", month: I18n.l(flow.reporting_months.first, format: :month_year)), with: "20"
    click_button I18n.t("activities.community_service.hours_input.continue")

    verify_page(page, title: I18n.t("activities.community_service.hours_input.heading",
      month: I18n.l(flow.reporting_months.second, format: :month_year),
      organization: "Helping Hands"))
    fill_in I18n.t("activities.community_service.hours_input.hours_label", month: I18n.l(flow.reporting_months.second, format: :month_year)), with: "10"
    click_button I18n.t("activities.community_service.hours_input.continue")

    # Document upload
    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "Helping Hands"),
      skip_axe_rules: %w[heading-order]
    )
    attach_file I18n.t("activities.document_uploads.new.input_label"), upload_path, make_visible: true
    click_button I18n.t("activities.document_uploads.new.continue")

    # Review page
    verify_page(page, title: I18n.t("activities.community_service.review.title", organization_name: "Helping Hands"))
    expect(page).to have_content "123 Main St, Springfield, Illinois"
    expect(page).to have_content "Jane Doe"
    expect(page).to have_content "jane@example.com"
    click_button I18n.t("activities.community_service.review.save")

    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_content "Helping Hands"

    # Add a Work Program activity
    within("[data-activity-type='work_programs']") do
      click_button I18n.t("activities.hub.add")
    end
    verify_page(page, title: I18n.t("activities.work_programs.title"))
    fill_in I18n.t("activities.work_programs.program_name"), with: "Resume Workshop"
    fill_in I18n.t("activities.work_programs.organization_address"), with: "123 Main St, Baton Rouge, LA"
    fill_in I18n.t("activities.work_programs.hours"), with: "6"
    fill_in I18n.t("activities.work_programs.date"), with: (Date.current.beginning_of_month - 1.day).strftime("%m/%d/%Y")
    click_button I18n.t("activities.work_programs.add")
    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "Resume Workshop"),
      skip_axe_rules: %w[heading-order]
    )
    attach_file I18n.t("activities.document_uploads.new.input_label"), upload_path, make_visible: true
    click_button I18n.t("activities.document_uploads.new.continue")
    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_content "Resume Workshop"

    # Verify that the hub has the Community Service activity
    expect(page).to have_content I18n.t("activities.hub.title")
    expect(page).to have_content "Helping Hands"
    expect(page).to have_content I18n.t("activities.hub.cards.hours", count: 20)
    expect(page).to have_content I18n.t("activities.hub.cards.hours", count: 10)

    # Verify that the hub has the Work Programs activity
    expect(page).to have_content "Resume Workshop"
    expect(page).to have_content I18n.t("activities.hub.cards.hours", count: 6)

    click_button I18n.t("activities.hub.review_and_submit")
    verify_page(page, title: I18n.t("activities.summary.title", benefit: I18n.t("shared.benefit.sandbox")))

    volunteering = flow.volunteering_activities.last
    job_training = flow.job_training_activities.last

    expect(page).to have_content volunteering.organization_name
    expect(page).to have_content volunteering.formatted_address
    expect(page).to have_content volunteering.coordinator_name
    expect(page).to have_content volunteering.coordinator_email
    expect(page).to have_content I18n.l(flow.reporting_months.first, format: :month)
    expect(page).to have_content I18n.l(flow.reporting_months.second, format: :month)
    expect(page).to have_content job_training.program_name

    # /activities/summary
    click_button I18n.t("activities.summary.submit", agency_name: I18n.t("shared.agency_full_name.sandbox"))
    verify_page(page, title: I18n.t("activities.submit.title"))
    find("label[for='activity_flow_consent_to_submit']").click
    click_button I18n.t("activities.submit.confirm")

    # /activities/success
    verify_page(page, title: I18n.t("activities.success.show.title", agency_acronym: I18n.t("shared.agency_acronym.sandbox")))
    expect(page).to have_content I18n.t("activities.success.show.download_pdf")
  end

  it "completes the generic flow for the income activity" do
    visit URI(root_url).request_uri

    visit activities_flow_entry_path(client_agency_id: "sandbox") # This would normally be inferred
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    click_link I18n.t("activities.entries.show.continue")

    verify_page(page, title: I18n.t("activities.hub.title"))

    # Add an Employment activity
    within("[data-activity-type='employment']") do
      click_button I18n.t("activities.hub.add")
    end
    verify_page(page, title: I18n.t("cbv.employer_searches.show.activity_flow.header"))
    @e2e.replay_modal_callbacks(page.driver.browser) do
      click_button "Paychex"
    end
    @e2e.record_modal_callbacks(page.driver.browser) do
      argyle_container = find("div[id*=\"argyle-link-root\"]", visible: :all)
      page.within(argyle_container.shadow_root) do
        find('[name="username"]', wait: 10).fill_in(with: "test_1")
        find('[name="password"]').fill_in(with: "passgood")
        find('[data-hook="connect-button"]').click
        wait_for_idle(page)
        find('[name="legacy_mfa_token"]', wait: 30).fill_in(with: "8081")
        wait_for_idle(page)
        find('[data-hook="connect-button"]', wait: 30).click
      end

      # Wait for Argyle modal to disappear
      find_all("div[id*=\"argyle-link-root\"]", visible: :all, maximum: 0, minimum: nil, wait: 30)
    end
    # /activities/income/synchronizations
    verify_page(page, title: I18n.t("cbv.synchronizations.show.activity_flow.header"), wait: 15)
    # /activities/income/payment_details
    @e2e.replay_webhooks
    verify_page(page, title: I18n.t("cbv.payment_details.show.activity_flow.header", employer_name: ""), wait: 60)
    fill_in "payroll_account[additional_information]",
      with: "Some kind of additional information"
    click_button I18n.t("cbv.payment_details.show.continue")
    verify_page(page, title: I18n.t("activities.hub.title"))

    click_button I18n.t("activities.hub.review_and_submit")
    verify_page(page, title: I18n.t("activities.summary.title", benefit: I18n.t("shared.benefit.sandbox")))

    # /activities/summary
    click_button I18n.t("activities.summary.submit", agency_name: I18n.t("shared.agency_full_name.sandbox"))
    verify_page(page, title: I18n.t("activities.submit.title"))
    find("label[for='activity_flow_consent_to_submit']").click
    click_button I18n.t("activities.submit.confirm")

    # /activities/success
    verify_page(page, title: I18n.t("activities.success.show.title", agency_acronym: I18n.t("shared.agency_acronym.sandbox")))
    expect(page).to have_content I18n.t("activities.success.show.download_pdf")
  end

  it "returns to hub with empty state for education when no records are found" do
    visit URI(root_url).request_uri

    visit activities_flow_entry_path(client_agency_id: "sandbox") # This would normally be inferred
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    click_link I18n.t("activities.entries.show.continue")

    verify_page(page, title: I18n.t("activities.hub.title"))

    # Add an Education activity
    within("[data-activity-type='education']") do
      click_button I18n.t("activities.hub.add")
    end
    performing_active_jobs do
      click_button I18n.t("activities.education.new.continue")
      verify_page(page, title: I18n.t("activities.education.show.header")) # /activities/education/123 (loading page)
    end
    verify_page(page, title: I18n.t("activities.education.edit.header"), wait: 10) # /activities/education/123/edit (show page)
    find("a", text: I18n.t("activities.education.edit.no_records_found.return_button")).click

    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_content I18n.t("activities.hub.empty.education")
  end

  it "completes submission flow when education enrollment data exists" do
    visit URI(root_url).request_uri

    visit activities_flow_entry_path(client_agency_id: "sandbox") # This would normally be inferred
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    click_link I18n.t("activities.entries.show.continue")

    verify_page(page, title: I18n.t("activities.hub.title"))

    current_flow = ActivityFlow.order(created_at: :desc).first
    education_activity = create(:education_activity, activity_flow: current_flow, status: :succeeded)
    create(:nsc_enrollment_term, education_activity:, school_name: "Test University")

    visit activities_flow_root_path
    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_content "Test University"

    click_button I18n.t("activities.hub.review_and_submit")
    verify_page(page, title: I18n.t("activities.summary.title", benefit: I18n.t("shared.benefit.sandbox")))
    expect(page).to have_content "Test University"

    click_button I18n.t("activities.summary.submit", agency_name: I18n.t("shared.agency_full_name.sandbox"))
    verify_page(page, title: I18n.t("activities.submit.title"))
    find("label[for='activity_flow_consent_to_submit']").click
    click_button I18n.t("activities.submit.confirm")

    verify_page(page, title: I18n.t("activities.success.show.title", agency_acronym: I18n.t("shared.agency_acronym.sandbox")))
    expect(page).to have_content I18n.t("activities.success.show.download_pdf")
  end

  it "supports editing a community service activity through the full flow" do # rubocop:disable RSpec/ExampleLength
    upload_path = Rails.root.join("spec/fixtures/files/document_upload.pdf")

    visit URI(root_url).request_uri
    visit activities_flow_entry_path(client_agency_id: "sandbox")
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.title"))

    flow = ActivityFlow.last
    month1 = flow.reporting_months.first
    month2 = flow.reporting_months.second
    month1_label = I18n.l(month1, format: :month_year)
    month2_label = I18n.l(month2, format: :month_year)

    # --- Step 1: Create a new CS activity ---
    within("[data-activity-type='community_service']") do
      click_button I18n.t("activities.hub.add")
    end
    verify_page(page, title: I18n.t("activities.community_service.new_title"))
    fill_in I18n.t("activities.community_service.organization_name"), with: "Helping Hands"
    fill_in I18n.t("activities.community_service.street_address"), with: "123 Main St"
    fill_in I18n.t("activities.community_service.city"), with: "Springfield"
    select "Illinois", from: I18n.t("activities.community_service.state")
    fill_in I18n.t("activities.community_service.zip_code"), with: "62701"
    fill_in I18n.t("activities.community_service.coordinator_name"), with: "Jane Doe"
    fill_in I18n.t("activities.community_service.coordinator_email"), with: "jane@example.com"
    click_button I18n.t("activities.community_service.continue")

    # Hours input month 1
    verify_page(page, title: I18n.t("activities.community_service.hours_input.heading",
      month: month1_label, organization: "Helping Hands"))
    fill_in I18n.t("activities.community_service.hours_input.hours_label", month: month1_label), with: "20"
    click_button I18n.t("activities.community_service.hours_input.continue")

    # Hours input month 2
    verify_page(page, title: I18n.t("activities.community_service.hours_input.heading",
      month: month2_label, organization: "Helping Hands"))
    fill_in I18n.t("activities.community_service.hours_input.hours_label", month: month2_label), with: "10"
    click_button I18n.t("activities.community_service.hours_input.continue")

    # Document upload
    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "Helping Hands"),
      skip_axe_rules: %w[heading-order]
    )
    attach_file I18n.t("activities.document_uploads.new.input_label"), upload_path, make_visible: true
    click_button I18n.t("activities.document_uploads.new.continue")

    # Review page
    verify_page(page, title: I18n.t("activities.community_service.review.title", organization_name: "Helping Hands"))
    click_button I18n.t("activities.community_service.review.save")

    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_content "Helping Hands"

    # --- Step 2: Edit the activity from the hub ---
    click_link I18n.t("activities.hub.edit")

    # Edit org info page
    verify_page(page, title: I18n.t("activities.community_service.edit_title"))
    fill_in I18n.t("activities.community_service.organization_name"), with: "Updated Org"
    click_button I18n.t("activities.community_service.continue")

    # Hours input month 1 (edit flow)
    verify_page(page, title: I18n.t("activities.community_service.hours_input.heading",
      month: month1_label, organization: "Updated Org"))
    fill_in I18n.t("activities.community_service.hours_input.hours_label", month: month1_label), with: "25"
    click_button I18n.t("activities.community_service.hours_input.continue")

    # Hours input month 2 (edit flow)
    verify_page(page, title: I18n.t("activities.community_service.hours_input.heading",
      month: month2_label, organization: "Updated Org"))
    fill_in I18n.t("activities.community_service.hours_input.hours_label", month: month2_label), with: "15"
    click_button I18n.t("activities.community_service.hours_input.continue")

    # Document upload (edit flow)
    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "Updated Org"),
      skip_axe_rules: %w[heading-order]
    )
    attach_file I18n.t("activities.document_uploads.new.input_label"), upload_path, make_visible: true
    click_button I18n.t("activities.document_uploads.new.continue")

    # Review page (edit flow - button should say "Save changes")
    verify_page(page, title: I18n.t("activities.community_service.review.title", organization_name: "Updated Org"))
    expect(page).to have_button I18n.t("activities.hub.save")

    # --- Step 3: Edit a single month from the review page ---
    # Click Edit on month 1 — should go to hours input and return directly to review
    edit_links = all("a", text: I18n.t("activities.community_service.review.edit"))
    edit_links.first.click

    verify_page(page, title: I18n.t("activities.community_service.hours_input.heading",
      month: month1_label, organization: "Updated Org"))
    fill_in I18n.t("activities.community_service.hours_input.hours_label", month: month1_label), with: "30"
    click_button I18n.t("activities.hub.save")

    # Should go directly back to review, NOT to month 2
    verify_page(page, title: I18n.t("activities.community_service.review.title", organization_name: "Updated Org"))
    expect(page).to have_content "30"

    # --- Step 4: Validation guard — cannot set all months to 0 from review ---
    # First, set month 2 to 0 via edit from review
    edit_links = all("a", text: I18n.t("activities.community_service.review.edit"))
    edit_links.last.click

    verify_page(page, title: I18n.t("activities.community_service.hours_input.heading",
      month: month2_label, organization: "Updated Org"))
    fill_in I18n.t("activities.community_service.hours_input.hours_label", month: month2_label), with: "0"
    click_button I18n.t("activities.hub.save")

    # Should succeed — month 1 still has 30 hours
    verify_page(page, title: I18n.t("activities.community_service.review.title", organization_name: "Updated Org"))

    # Now try to set month 1 to 0 — should fail validation
    edit_links = all("a", text: I18n.t("activities.community_service.review.edit"))
    edit_links.first.click

    verify_page(page, title: I18n.t("activities.community_service.hours_input.heading",
      month: month1_label, organization: "Updated Org"))
    fill_in I18n.t("activities.community_service.hours_input.hours_label", month: month1_label), with: "0"
    click_button I18n.t("activities.hub.save")

    # Should stay on hours input with an error
    expect(page).to have_content I18n.t("activities.community_service.hours_input.error_heading")

    # Fix it — set to a valid value and save
    fill_in I18n.t("activities.community_service.hours_input.hours_label", month: month1_label), with: "5"
    click_button I18n.t("activities.hub.save")

    # Back to review, then save to hub
    verify_page(page, title: I18n.t("activities.community_service.review.title", organization_name: "Updated Org"))
    click_button I18n.t("activities.hub.save")

    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_content "Updated Org"
  end

  it "blocks activity hub access when not enabled" do
    stub_environment_variable("ACTIVITY_HUB_ENABLED", nil) do
      visit activities_flow_root_path
      expect(page).to have_content(I18n.t("pages.home.header"))
      visit new_activities_flow_volunteering_path
      expect(page).to have_content(I18n.t("pages.home.header"))
    end
  end
end
