require "rails_helper"

RSpec.describe "e2e Employment-focused review page", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  around do |ex|
    override_supported_providers([ :argyle ]) do
      e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      e2e.use_recording("e2e_activity_flow", &ex)
    end
  end

  it "shows the self-attested job and supports submitting the report" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
    upload_path = Rails.root.join("spec/fixtures/files/document_upload.pdf")
    invitation = create(:activity_flow_invitation, employment_focused: true)

    visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 1)
    click_link I18n.t("activities.entries.show.employment_focused.get_started")

    flow = ActivityFlow.last
    month_label = I18n.l(flow.reporting_months.first, format: :month)

    # --- Add a single self-attested, manually-entered paid job ---
    verify_page(page, title: I18n.t("activities.employment.add_your_work.show.employment_focused.header"))

    find("label[for='add_work_method_enter_paid_manually']").click
    click_button I18n.t("continue")

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

    verify_page(page, title: I18n.t("activities.employment.hours_input.heading", organization: "Gainesville Wrecking"))
    fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: month_label), with: "500"
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: month_label), with: "40"
    click_button I18n.t("activities.employment.hours_input.continue")

    verify_page(
      page,
      title: I18n.t("activities.document_uploads.new.title", name: "Gainesville Wrecking"),
      skip_axe_rules: %w[heading-order]
    )
    attach_file I18n.t("activities.document_uploads.new.input_label"), upload_path, make_visible: true
    click_button I18n.t("activities.document_uploads.new.continue")

    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Gainesville Wrecking"))
    click_button I18n.t("activities.employment.review.save")

    # --- Saving the review prompts for additional jobs before showing the summary ---
    verify_page(page, title: I18n.t("activities.employment.add_your_work.add_jobs.header"))
    find("label[for='additional_jobs_false']").click
    click_button I18n.t("activities.employment.add_your_work.add_jobs.submit")

    # --- Saving the review returns to the employment-focused review page ---
    verify_page(page, title: I18n.t("activities.activities.employment_focused_review.header"))
    expect(page).to have_content(
      I18n.t("activities.activities.employment_focused_review.employment_header", count: 1, employer_name: "Gainesville Wrecking")
    )
    expect(page).to have_content(I18n.t("activities.activities.employment_focused_review.employer_information"))
    expect(page).to have_content("Gainesville Wrecking")
    expect(page).to have_content("942 W Harlan Ave, Gainesville, FL 32611")
    expect(page).to have_content("Donny Spears")
    expect(page).to have_content("donny@gainesvillewrecking.com")
    expect(page).to have_content("(415) 344-8009")

    expect(page).to have_content(I18n.t("activities.activities.employment_focused_review.hours_and_income"))
    expect(page).to have_content(I18n.l(flow.reporting_months.first, format: :month_year))
    expect(page).to have_content("$500.00")
    expect(page).to have_content("40")

    # --- The uploaded document is listed with a working remove link ---
    expect(page).to have_content("document_upload.pdf")
    expect(page).to have_link(nil, href: /document_uploads/)

    # --- Submitting is blocked until the consent checkbox is checked ---
    click_button I18n.t("activities.activities.employment_focused_review.submit", agency_name: "Test Agency")
    expect(page).to have_content(I18n.t("activities.submit.consent_required"))

    # --- The error re-renders the same employment-focused review page, not the generic summary ---
    verify_page(page, title: I18n.t("activities.activities.employment_focused_review.header"))
    expect(page).to have_content(
      I18n.t("activities.activities.employment_focused_review.employment_header", count: 1, employer_name: "Gainesville Wrecking")
    )

    find("label[for='activity_flow_consent_to_submit']").click
    click_button I18n.t("activities.activities.employment_focused_review.submit", agency_name: "Test Agency")

    verify_page(page, title: I18n.t("activities.success.show.title", agency_acronym: I18n.t("shared.agency_acronym.sandbox")))
  end
end
