require "rails_helper"

RSpec.describe "e2e Activity flow back and exit navigation", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  around do |ex|
    override_supported_providers([ :argyle ]) do
      e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      e2e.use_recording("e2e_activity_flow", &ex)
    end
  end

  it "handles back button, browser back, and exit with confirmation modal" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
    modal_heading = I18n.t("activities.activity_header_component.modal.heading")

    visit URI(root_url).request_uri
    visit activities_flow_entry_path(client_agency_id: "sandbox")
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.title"))

    flow = ActivityFlow.last
    month1_label = I18n.l(flow.reporting_months.first, format: :month_year)

    # --- /new page: browser back triggers modal (always_confirm, no back_url) → hub ---
    within("[data-activity-type='community_service']") { click_button I18n.t("activities.hub.add") }
    verify_page(page, title: I18n.t("activities.community_service.new_title"))

    page.go_back
    expect(page).to have_content(modal_heading)
    find("[data-action*='activity-flow-header#confirmExit']").click
    verify_page(page, title: I18n.t("activities.hub.title"))

    # --- Setup: create a community service activity to reach the hours input page ---
    within("[data-activity-type='community_service']") { click_button I18n.t("activities.hub.add") }
    verify_page(page, title: I18n.t("activities.community_service.new_title"))
    fill_in I18n.t("activities.community_service.organization_name"), with: "Test Org"
    fill_in I18n.t("activities.community_service.street_address"), with: "123 Main St"
    fill_in I18n.t("activities.community_service.city"), with: "Springfield"
    fill_in I18n.t("activities.community_service.state"), with: "Illinois"
    find(".usa-combo-box__list-option", text: "Illinois (IL)").click
    fill_in I18n.t("activities.community_service.zip_code"), with: "62701"
    fill_in I18n.t("activities.community_service.coordinator_name"), with: "Jane Doe"
    fill_in I18n.t("activities.community_service.coordinator_email"), with: "jane@example.com"
    click_button I18n.t("activities.community_service.continue")

    hours_title = I18n.t("activities.community_service.hours_input.heading",
      month: month1_label, organization: "Test Org")
    edit_title = I18n.t("activities.community_service.edit_title")
    hours_label = I18n.t("activities.community_service.hours_input.hours_label", month: month1_label)
    verify_page(page, title: hours_title)

    # --- Hours page (clean form): UI back button navigates to previous page ---
    find(".back-nav__link").click
    verify_page(page, title: edit_title)

    # Return to hours input
    click_button I18n.t("activities.community_service.continue")
    verify_page(page, title: hours_title)

    # --- Hours page (dirty form): browser back → modal → confirm → previous page (not hub) ---
    fill_in hours_label, with: "20"
    page.go_back
    expect(page).to have_content(modal_heading)
    find("[data-action*='activity-flow-header#confirmExit']").click
    verify_page(page, title: edit_title)

    # Return to hours input
    click_button I18n.t("activities.community_service.continue")
    verify_page(page, title: hours_title)

    # --- Hours page (dirty form): modal "Back" button dismisses modal, stays on page ---
    fill_in hours_label, with: "20"
    find(".back-nav__link").click
    expect(page).to have_content(modal_heading)
    click_button I18n.t("activities.activity_header_component.modal.back_button")
    expect(page).to have_no_content(modal_heading)
    expect(page).to have_content(hours_title)

    # --- Hours page (dirty form): modal X close button dismisses modal, stays on page ---
    find(".activity-header-title__exit-link").click
    expect(page).to have_content(modal_heading)
    find("button.usa-modal__close").click
    expect(page).to have_no_content(modal_heading)
    expect(page).to have_content(hours_title)

    # --- Hours page (dirty form): exit (X) → modal → confirm → hub ---
    fill_in hours_label, with: "15"
    find(".activity-header-title__exit-link").click
    expect(page).to have_content(modal_heading)
    find("[data-action*='activity-flow-header#confirmExit']").click
    verify_page(page, title: I18n.t("activities.hub.title"))

    # --- Setup: create a new community service activity and progress through to document upload ---
    upload_path = Rails.root.join("spec/fixtures/files/document_upload.pdf")
    month2_label = I18n.l(flow.reporting_months.second, format: :month_year)

    within("[data-activity-type='community_service']") { click_button I18n.t("activities.hub.add") }
    verify_page(page, title: I18n.t("activities.community_service.new_title"))
    fill_in I18n.t("activities.community_service.organization_name"), with: "Nav Org"
    fill_in I18n.t("activities.community_service.street_address"), with: "456 Elm St"
    fill_in I18n.t("activities.community_service.city"), with: "Springfield"
    fill_in I18n.t("activities.community_service.state"), with: "Illinois"
    find(".usa-combo-box__list-option", text: "Illinois (IL)").click
    fill_in I18n.t("activities.community_service.zip_code"), with: "62701"
    fill_in I18n.t("activities.community_service.coordinator_name"), with: "Jane Doe"
    fill_in I18n.t("activities.community_service.coordinator_email"), with: "jane@example.com"
    click_button I18n.t("activities.community_service.continue")

    verify_page(page, title: I18n.t("activities.community_service.hours_input.heading",
      month: month1_label, organization: "Nav Org"))
    fill_in I18n.t("activities.community_service.hours_input.hours_label", month: month1_label), with: "20"
    click_button I18n.t("activities.community_service.hours_input.continue")

    month2_hours_title = I18n.t("activities.community_service.hours_input.heading",
      month: month2_label, organization: "Nav Org")
    verify_page(page, title: month2_hours_title)
    fill_in I18n.t("activities.community_service.hours_input.hours_label", month: month2_label), with: "10"
    click_button I18n.t("activities.community_service.hours_input.continue")

    doc_upload_title = I18n.t("activities.document_uploads.new.title", name: "Nav Org")
    review_title = I18n.t("activities.community_service.review.title", organization_name: "Nav Org")

    # --- Document upload (clean form): UI back → month 2 hours ---
    verify_page(page, title: doc_upload_title, skip_axe_rules: %w[heading-order])
    find(".back-nav__link").click
    verify_page(page, title: month2_hours_title)

    # Return to document upload
    click_button I18n.t("activities.community_service.hours_input.continue")
    verify_page(page, title: doc_upload_title, skip_axe_rules: %w[heading-order])

    # --- Document upload (dirty form): browser back → modal → confirm → month 2 hours ---
    attach_file I18n.t("activities.document_uploads.new.input_label"), upload_path, make_visible: true
    page.go_back
    expect(page).to have_content(modal_heading)
    find("[data-action*='activity-flow-header#confirmExit']").click
    verify_page(page, title: month2_hours_title)

    # Return to document upload, attach file, and continue to review
    click_button I18n.t("activities.community_service.hours_input.continue")
    verify_page(page, title: doc_upload_title, skip_axe_rules: %w[heading-order])
    attach_file I18n.t("activities.document_uploads.new.input_label"), upload_path, make_visible: true
    click_button I18n.t("activities.document_uploads.new.continue")

    # --- Review page (clean form): UI back → document upload ---
    verify_page(page, title: review_title)
    find(".back-nav__link").click
    verify_page(page, title: doc_upload_title, skip_axe_rules: %w[heading-order])

    # Return to review
    click_button I18n.t("activities.document_uploads.new.continue")
    verify_page(page, title: review_title)

    # --- Review page (dirty form): browser back → modal → confirm → document upload ---
    fill_in "volunteering_activity_additional_comments", with: "Some notes"
    page.go_back
    expect(page).to have_content(modal_heading)
    find("[data-action*='activity-flow-header#confirmExit']").click
    verify_page(page, title: doc_upload_title, skip_axe_rules: %w[heading-order])
  end
end
