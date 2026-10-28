require "rails_helper"

RSpec.describe "Activity input errors", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation, client_agency_id: "sandbox") }
  let(:flow) { invitation.activity_flows.order(:created_at).last }

  before do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 1)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: I18n.t("shared.benefit.sandbox")))
  end

  after do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  def verify_input_error(title:, form_id:, message:)
    # The title is unchanged after submission. Wait for the error before Axe runs.
    expect(page).to have_selector(".usa-alert--error.usa-alert--slim", text: message, count: 1)
    verify_page(page, title: title)
    expect(page).to have_no_selector(".usa-alert__heading")
    expect(page).to have_selector(".usa-alert--slim:focus[data-error-summary-form-id-value='#{form_id}']")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
  end

  def expect_invalid_field(field_id)
    expect(page).to have_selector("##{field_id}.usa-input--error[aria-invalid='true']")
    expect(page).to have_selector("##{field_id}_error.usa-error-message")
    expect(find("##{field_id}")["aria-describedby"]).to include("#{field_id}_error")
  end

  context "with community service hours" do
    let(:activity) { create(:volunteering_activity, activity_flow: flow) }
    let(:title) do
      I18n.t("activities.community_service.hours_input.heading",
        month: I18n.l(flow.reporting_months.first, format: :month_year), organization: activity.organization_name)
    end

    before do
      visit edit_activities_flow_community_service_month_path(community_service_id: activity, id: 0)
      verify_page(page, title: title)
      click_button I18n.t("activities.community_service.hours_input.continue")
    end

    it "shows a slim summary and an inline hours error until the next submission" do
      verify_input_error(title: title, form_id: "hours_input_form",
        message: I18n.t("activities.community_service.hours_input.error_body"))
      expect_invalid_field("volunteering_activity_month_hours")
      fill_in "volunteering_activity_month_hours", with: "5"
      expect(page).to have_selector(".usa-alert--slim")
      expect(page).to have_selector("#volunteering_activity_month_hours_error")
      expect(activity.activity_months).to be_empty
    end
  end

  context "with work program hours" do
    let(:activity) { create(:job_training_activity, activity_flow: flow) }
    let(:title) do
      I18n.t("activities.work_programs.hours_input.heading",
        month: I18n.l(flow.reporting_months.first, format: :month_year), organization: activity.program_name)
    end

    before do
      visit edit_activities_flow_job_training_month_path(job_training_id: activity, id: 0)
      verify_page(page, title: title)
      click_button I18n.t("activities.work_programs.hours_input.continue")
    end

    it "shows the same slim summary and inline field styling" do
      verify_input_error(title: title, form_id: "hours_input_form",
        message: I18n.t("activities.work_programs.hours_input.error_body"))
      expect_invalid_field("job_training_activity_month_hours")
      expect(activity.activity_months).to be_empty
    end
  end

  context "with paid employment" do
    let(:activity) { create(:employment_activity, activity_flow: flow) }
    let(:title) { I18n.t("activities.employment.hours_input.heading", organization: activity.employer_name) }

    before do
      visit edit_activities_flow_income_employment_month_path(employment_id: activity, id: 0)
      verify_page(page, title: title)
      click_button I18n.t("activities.employment.hours_input.continue")
    end

    it "highlights missing income while keeping optional hours unmarked" do
      verify_input_error(title: title, form_id: "employment_month_form",
        message: I18n.t("activities.employment.hours_input.error_body"))
      expect_invalid_field("employment_activity_month_gross_income")
      expect(page).to have_no_selector("#employment_activity_month_hours.usa-input--error")
      expect(page).to have_selector(".usa-input-group--error #employment_activity_month_gross_income")
      expect(activity.activity_months).to be_empty
    end

    context "when income and hours are both zero" do
      before do
        fill_in "employment_activity_month_gross_income", with: "0"
        fill_in "employment_activity_month_hours", with: "0"
        click_button I18n.t("activities.employment.hours_input.continue")
      end

      it "provides inline feedback for the existing all-zero validation" do
        expect(page).to have_selector(".usa-error-message", text: I18n.t("activities.employment.hours_input.error_body"))
        verify_input_error(title: title, form_id: "employment_month_form",
          message: I18n.t("activities.employment.hours_input.error_body"))
        expect_invalid_field("employment_activity_month_gross_income")
        expect(activity.activity_months).to be_empty
      end
    end
  end

  context "with unpaid employment hours" do
    let(:activity) { create(:employment_activity, activity_flow: flow, compensation_type: :unpaid_or_in_kind) }
    let(:title) { I18n.t("activities.employment.hours_input.unpaid_or_in_kind.heading", organization: activity.employer_name) }

    before do
      visit edit_activities_flow_income_employment_month_path(employment_id: activity, id: 0)
      verify_page(page, title: title)
      click_button I18n.t("activities.employment.hours_input.continue")
    end

    it "shows the hours error with a slim banner" do
      verify_input_error(title: title, form_id: "employment_month_form",
        message: I18n.t("activities.employment.hours_input.unpaid_or_in_kind.field_error"))
      expect_invalid_field("employment_activity_month_hours")
      expect(activity.activity_months).to be_empty
    end
  end

  context "with employment month selection" do
    let(:activity) { create(:employment_activity, activity_flow: flow) }
    let(:title) { I18n.t("activities.employment.month_selections.edit.title", employer_name: activity.employer_name) }

    before do
      flow.update!(reporting_window_months: 3)
      visit edit_activities_flow_income_employment_month_selection_path(employment_id: activity)
      verify_page(page, title: title)
      click_button I18n.t("activities.employment.month_selections.edit.continue")
    end

    it "keeps the visible selection instruction below the slim error banner" do
      verify_input_error(title: title, form_id: "employment_month_selection_form",
        message: I18n.t("activities.employment.month_selections.edit.error_body"))
      expect(page).to have_selector("legend:not(.usa-sr-only)", text: I18n.t("activities.employment.month_selections.edit.legend"))
      expect(page).to have_selector("input[type='checkbox']", count: 3, visible: :all)
      expect(activity.reload.selected_months).to be_empty
    end
  end

  context "with self-attested education terms" do
    let(:activity) { create(:education_activity, activity_flow: flow, data_source: :fully_self_attested, school_name: "Test School") }
    let(:title) { I18n.t("activities.education.add_your_term.edit.title", school_name: activity.school_name) }

    before do
      visit edit_activities_flow_education_add_your_term_path(education_id: activity)
      verify_page(page, title: title)
      click_button I18n.t("activities.education.add_your_term.edit.continue")
    end

    it "highlights all three required fields with linked inline errors" do
      verify_input_error(title: title, form_id: "education-term-form",
        message: I18n.t("activities.education.add_your_term.errors.information_body"))
      expect_invalid_field("education_activity_self_attested_term_start")
      expect_invalid_field("education_activity_self_attested_term_end")
      expect_invalid_field("education_activity_self_attested_enrollment_status")
      fill_in "education_activity_self_attested_term_start", with: "01/2026"
      expect(page).to have_selector(".usa-alert--slim")
      expect(page).to have_selector("#education_activity_self_attested_term_start_error")
      expect(activity.reload.self_attested_term_start).to be_nil
    end

    context "with invalid term dates" do
      before do
        fill_in "education_activity_self_attested_term_start", with: "55/2026"
        fill_in "education_activity_self_attested_term_end", with: "12/2026"
        select I18n.t("activities.education.add_your_term.edit.enrollment_status_options.full_time"), from: "education_activity_self_attested_enrollment_status"
        click_button I18n.t("activities.education.add_your_term.edit.continue")
      end

      it "preserves the invalid value and uses the same error presentation" do
        verify_input_error(title: title, form_id: "education-term-form",
          message: I18n.t("activities.education.add_your_term.errors.dates_body"))
        expect_invalid_field("education_activity_self_attested_term_start")
        expect(page).to have_field("education_activity_self_attested_term_start", with: "55/2026")
      end
    end
  end

  context "with NSC term credit hours" do
    let(:activity) { create(:education_activity, activity_flow: flow, data_source: :partially_self_attested, status: :succeeded) }
    let(:term) { create(:nsc_enrollment_term, :less_than_half_time, education_activity: activity, school_name: "Test School") }
    let(:title) { I18n.t("activities.education.term_credit_hours.heading", school_name: term.school_name) }

    before do
      term
      visit edit_activities_flow_education_term_credit_hour_path(education_id: activity, id: 0)
      verify_page(page, title: title)
      click_button I18n.t("activities.education.term_credit_hours.continue")
    end

    it "shows the slim summary and inline credit-hours error" do
      verify_input_error(title: title, form_id: "education_term_credit_hours_form",
        message: I18n.t("activities.education.term_credit_hours.error_body_multi_month"))
      expect_invalid_field("nsc_enrollment_term_credit_hours")
      expect(term.reload.credit_hours).to be_nil
    end
  end
end
