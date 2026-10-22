require "rails_helper"

RSpec.describe "Unpaid-only community engagement", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:agency_name) { I18n.t("shared.agency_full_name.sandbox") }
  let(:agency_website) { Rails.application.config.client_agencies["sandbox"].agency_contact_website }
  let(:renewal_instructions) { I18n.t("activities.success.show.head_of_household_description_html", agency_website: agency_website) }
  let(:agency_website_link_text) { Capybara.string(renewal_instructions).find("a").text }

  it "launches and completes unpaid work using the employment activity flow" do
    # Launcher: create a tokenized unpaid-work flow.
    visit launcher_advanced_path
    # Existing advanced-launcher headings and controls lack accessible labels.
    verify_page(page, title: "Emmy Launcher", skip_axe_rules: %w[heading-order label select-name])
    click_button "1 month"
    check I18n.t("launcher.advanced.unpaid_work_only.label"), allow_label_click: true
    launched_window = window_opened_by { click_button "Open in new tab" }

    within_window launched_window do
      # Entry: start reporting community engagement.
      verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
      click_link I18n.t("activities.entries.show.continue")

      # Hub: add unpaid work directly.
      verify_page(page, title: I18n.t("activities.hub.empty_state_title"))
      within("[data-activity-type='unpaid_work']") { click_button I18n.t("activities.hub.add") }

      # Work information: confirm the unpaid form is shown.
      verify_page(page, title: I18n.t("activities.employment_info.unpaid_or_in_kind.title"))
      click_link I18n.t("activities.activity_header_component.back")

      # Hub: return and start adding unpaid work again.
      verify_page(page, title: I18n.t("activities.hub.empty_state_title"))
      within("[data-activity-type='unpaid_work']") { click_button I18n.t("activities.hub.add") }

      # Work information: confirm the unpaid form is shown.
      verify_page(page, title: I18n.t("activities.employment_info.unpaid_or_in_kind.title"))
      fill_in I18n.t("activities.employment_info.unpaid_or_in_kind.employer_name"), with: "Example unpaid work"
      click_button I18n.t("activities.employment_info.continue")

      # Monthly hours: report time worked without an income field.
      verify_page(page, title: I18n.t("activities.employment.hours_input.unpaid_or_in_kind.heading", organization: "Example unpaid work"))
      activity = EmploymentActivity.last
      month = activity.activity_flow.reporting_months.first
      expect(page).to have_no_selector('input[name="employment_activity_month[gross_income]"]')
      fill_in I18n.t("activities.employment.hours_input.hours_label", month: I18n.l(month, format: :month)), with: "12"
      click_button I18n.t("activities.employment.hours_input.continue")

      # Documents: continue without uploading a document.
      verify_page(page, title: I18n.t("activities.document_uploads.new.title", name: "Example unpaid work"), skip_axe_rules: %w[heading-order])
      click_button I18n.t("activities.document_uploads.new.continue")

      # Review: save the unpaid work activity.
      verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Example unpaid work"))
      click_button I18n.t("activities.employment.review.save")

      # Hub: verify the saved activity and hours.
      verify_page(page, title: I18n.t("activities.hub.in_progress_state_title"))
      within("[data-activity-type='unpaid_work']") do
        expect(page).to have_text(I18n.t("activities.hub.cards.hours", count: "12"))
        expect(page).to have_no_text("$0.00")
      end

      expect(activity.reload).not_to be_draft
      expect(activity).to be_unpaid_or_in_kind
      expect(activity.activity_flow).to be_unpaid_work_only
      expect(activity.employment_activity_months.sole).to have_attributes(hours: 12, gross_income: 0)

      # Edit: the unpaid work information is preserved.
      visit edit_activities_flow_income_employment_path(id: activity, from_edit: 1)
      verify_page(page, title: I18n.t("activities.employment_info.unpaid_or_in_kind.title"))
      expect(page).to have_field(I18n.t("activities.employment_info.unpaid_or_in_kind.employer_name"), with: "Example unpaid work")

      # Submit: complete the tokenized community engagement flow.
      visit activities_flow_root_path
      verify_page(page, title: I18n.t("activities.hub.title"))
      click_button I18n.t("activities.hub.review_and_submit")
      verify_page(page, title: I18n.t("activities.summary.title", benefit: I18n.t("shared.benefit.sandbox")))
      find("label[for='activity_flow_consent_to_submit']").click
      click_button I18n.t("activities.summary.submit", agency_name: agency_name)

      verify_page(page, title: I18n.t("activities.success.show.title", agency_name: agency_name))
      expect(page).to have_selector("p", text: I18n.t("activities.success.show.next_steps_description", agency_name: agency_name), exact_text: true, normalize_ws: true)
      expect(page).to have_link(I18n.t("activities.success.show.download_pdf"), href: activities_flow_submit_path(format: :pdf))
      expect(page).to have_text(I18n.t("activities.success.show.household_member_description", agency_name: agency_name))
      expect(page).to have_link(agency_website_link_text, href: agency_website)
    end
  end
end
