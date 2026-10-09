require "rails_helper"

RSpec.describe "Employment-focused entry navigation", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:applicant) { create(:cbv_applicant, first_name: "Lisa", last_name: "Williams") }
  let(:invitation) { create(:activity_flow_invitation, employment_focused: true, cbv_applicant: applicant) }

  it "renders the employment-focused entry content and navigates to add-your-work screen" do
    visit activities_flow_start_path(token: invitation.auth_token)

    verify_page(page, title: I18n.t("activities.entries.show.employment_focused.header"))
    expect(page).to have_text("Reporting for Lisa Williams", count: 1)
    expect(page).to have_no_content(I18n.t("activities.entries.show.title", benefit: "Medicaid"))

    click_link I18n.t("activities.entries.show.employment_focused.get_started")

    verify_page(page, title: "Choose how you want to add your job")
    expect(page).to have_text("Reporting for Lisa Williams", count: 1)
  end

  it "renders the generic entry content when not employment_focused" do
    non_employment_invitation = create(:activity_flow_invitation, employment_focused: false, cbv_applicant: applicant)
    visit activities_flow_start_path(token: non_employment_invitation.auth_token)

    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    expect(page).to have_text("Reporting for Lisa Williams", count: 1)
    expect(page).to have_no_content(I18n.t("activities.entries.show.employment_focused.header"))

    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.empty_state_title"))
    expect(page).to have_text("Reporting for Lisa Williams", count: 1)
    within("[data-activity-type='employment']") { click_button I18n.t("activities.hub.add") }
    verify_page(page, title: "Choose how you want to add your work")
    expect(page).to have_text("Reporting for Lisa Williams", count: 1)
    expect(page).to have_no_text("Choose how you want to add your job")
    expect(page).to have_selector("label .text-bold", text: "Enter unpaid or in-kind work", exact_text: true)
  end

  context "the add_jobs page" do
    around do |ex|
      override_supported_providers([ :argyle ]) do
        e2e = E2e::MockingService.new(server_url: URI(page.server_url))
        e2e.use_recording("e2e_activity_flow", &ex)
      end
    end

    # Assumes the browser is already on the "add your work" page. Walks
    # through a single-month, manually-entered paid job and lands on the
    # add_jobs page.
    def add_manual_job(employer_name:, gross_income:, hours:, flow:)
      find("label[for='add_work_method_enter_paid_manually']").click
      click_button I18n.t("continue")

      verify_page(page, title: I18n.t("activities.employment_info.title"))
      expect(page).to have_text("Reporting for Lisa Williams", count: 1)
      fill_in I18n.t("activities.employment_info.employer_name"), with: employer_name
      fill_in I18n.t("activities.employment_info.street_address"), with: "942 W Harlan Ave"
      fill_in I18n.t("activities.employment_info.city"), with: "Gainesville"
      fill_in I18n.t("activities.employment_info.state"), with: "Florida"
      find(".usa-combo-box__list-option", text: "Florida (FL)").click
      fill_in I18n.t("activities.employment_info.zip_code"), with: "32611"
      fill_in I18n.t("activities.employment_info.contact_name"), with: "Donny Spears"
      fill_in I18n.t("activities.employment_info.contact_email"), with: "donny@gainesvillewrecking.com"
      fill_in I18n.t("activities.employment_info.contact_phone_number"), with: "(415) 344-8009"
      click_button I18n.t("activities.employment_info.continue")

      month_label = I18n.l(flow.reporting_months.first, format: :month)
      verify_page(page, title: I18n.t("activities.employment.hours_input.heading", organization: employer_name))
      expect(page).to have_text("Reporting for Lisa Williams", count: 1)
      fill_in I18n.t("activities.employment.hours_input.gross_income_label", month: month_label), with: gross_income
      fill_in I18n.t("activities.employment.hours_input.hours_label", month: month_label), with: hours
      click_button I18n.t("activities.employment.hours_input.continue")

      verify_page(
        page,
        title: I18n.t("activities.document_uploads.new.title", name: employer_name),
        skip_axe_rules: %w[heading-order]
      )
      click_button I18n.t("activities.document_uploads.new.continue")

      verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: employer_name))
      expect(page).to have_text("Reporting for Lisa Williams", count: 1)
      click_button I18n.t("activities.employment.review.save")
    end

    it "lists added jobs and supports adding another job or finishing" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 1)
      click_link I18n.t("activities.entries.show.employment_focused.get_started")

      flow = ActivityFlow.last

      # No jobs added yet — the summary box shouldn't render
      verify_page(page, title: I18n.t("activities.employment.add_your_work.show.employment_focused.header"))
      expect(page).to have_text("Reporting for Lisa Williams", count: 1)
      expect(page).to have_no_content(I18n.t("activities.employment.add_your_work.add_jobs.jobs_added_heading", count: 0))

      # --- Add the first job, landing on the add_jobs page afterward ---
      add_manual_job(employer_name: "Acme Co", gross_income: "500", hours: "40", flow: flow)

      verify_page(page, title: I18n.t("activities.employment.add_your_work.add_jobs.header"))
      expect(page).to have_text("Reporting for Lisa Williams", count: 1)
      expect(page).to have_content(flow.reporting_window_display)
      expect(page).to have_content(I18n.t("activities.employment.add_your_work.add_jobs.jobs_added_heading", count: 1))
      expect(page).to have_content(I18n.t("activities.employment.add_your_work.add_jobs.job_manual", name: "Acme Co"))

      # --- Submitting without selecting an option shows an error and stays on the page ---
      click_button I18n.t("activities.employment.add_your_work.add_jobs.submit")
      expect(page).to have_content(I18n.t("shared.next_path.notice_no_answer"))
      verify_page(page, title: I18n.t("activities.employment.add_your_work.add_jobs.header"))
      expect(page).to have_text("Reporting for Lisa Williams", count: 1)

      # --- Answering "yes" returns to the add-your-work page to add another job ---
      find("label[for='additional_jobs_true']").click
      click_button I18n.t("activities.employment.add_your_work.add_jobs.submit")
      verify_page(page, title: I18n.t("activities.employment.add_your_work.show.employment_focused.header"))
      expect(page).to have_text("Reporting for Lisa Williams", count: 1)

      # --- Add a second job, landing back on the add_jobs page with both jobs listed ---
      add_manual_job(employer_name: "Beta Staffing", gross_income: "300", hours: "20", flow: flow)

      verify_page(page, title: I18n.t("activities.employment.add_your_work.add_jobs.header"))
      expect(page).to have_text("Reporting for Lisa Williams", count: 1)
      expect(page).to have_content(I18n.t("activities.employment.add_your_work.add_jobs.jobs_added_heading", count: 2))
      expect(page).to have_content(I18n.t("activities.employment.add_your_work.add_jobs.job_manual", name: "Acme Co"))
      expect(page).to have_content(I18n.t("activities.employment.add_your_work.add_jobs.job_manual", name: "Beta Staffing"))

      # --- Answering "no" finishes and returns to the activity hub ---
      find("label[for='additional_jobs_false']").click
      click_button I18n.t("activities.employment.add_your_work.add_jobs.submit")
      verify_page(page, title: I18n.t("activities.hub.completed_state_title"))
      expect(page).to have_text("Reporting for Lisa Williams", count: 1)
    end
  end
end
