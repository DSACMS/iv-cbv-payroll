require "rails_helper"

RSpec.describe "Continuing without supporting documents", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation, client_agency_id: "sandbox") }
  let(:flow) { invitation.activity_flows.order(:created_at).last }
  let(:activity) { create(:employment_activity, activity_flow: flow) }
  let(:heading) { I18n.t("activities.document_uploads.new.empty_confirmation.heading") }
  let(:continue_without_uploading) { I18n.t("activities.document_uploads.new.empty_confirmation.continue") }
  let(:upload_title) { I18n.t("activities.document_uploads.new.title", name: activity.employer_name) }

  before do
    visit activities_flow_start_path(token: invitation.auth_token)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    activity.update_selected_months!([ flow.reporting_months.first ])
    create(:employment_activity_month, employment_activity: activity, month: flow.reporting_months.first, hours: 10, gross_income: 100)
    visit new_activities_flow_income_employment_document_upload_path(employment_id: activity)
    verify_page(page, title: upload_title, skip_axe_rules: %w[heading-order])
  end

  it "lets the user go back, dismiss with Escape, and explicitly continue to review" do
    click_button I18n.t("activities.document_uploads.new.continue")
    expect(page).to have_selector("[role='dialog'][aria-modal='true']", text: heading)
    expect(page).to be_axe_clean
    click_button I18n.t("activities.document_uploads.new.empty_confirmation.go_back")
    expect(page).to have_no_text(heading)
    expect(page).to have_selector("#document-upload-continue:focus")

    click_button I18n.t("activities.document_uploads.new.continue")
    find("button[aria-label='#{I18n.t('activities.document_uploads.new.empty_confirmation.close')}']").click
    expect(page).to have_no_text(heading)
    expect(page).to have_selector("#document-upload-continue:focus")

    click_button I18n.t("activities.document_uploads.new.continue")
    page.driver.browser.action.send_keys(:escape).perform
    expect(page).to have_no_text(heading)
    expect(page).to have_selector("#document-upload-continue:focus")

    click_button I18n.t("activities.document_uploads.new.continue")
    click_button continue_without_uploading
    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: activity.employer_name))
    expect(activity.reload.document_uploads).to be_empty
  end

  it "shows the session warning without submitting the empty upload form" do
    click_button I18n.t("activities.document_uploads.new.continue")
    expect(page).to have_text(heading)

    page.execute_script(<<~JS)
      window.uploadSubmissionCount = 0;
      document.getElementById("document-upload-form").addEventListener("submit", (event) => {
        window.uploadSubmissionCount += 1;
        event.preventDefault();
      });
      const modal = document.querySelector("[data-controller~=session]");
      const controller = window.Stimulus.getControllerForElementAndIdentifier(modal, "session");
      controller.timeoutValue = 300;
      controller.setupTimers();
    JS

    expect(page).to have_text(I18n.t("session_timeout.modal.heading"))
    expect(page).to have_no_text(heading)
    expect(page.evaluate_script("window.uploadSubmissionCount")).to eq(0)
    expect(page).to have_current_path(new_activities_flow_income_employment_document_upload_path(employment_id: activity))
    click_button I18n.t("session_timeout.modal.extend_button")
    verify_page(page, title: upload_title, skip_axe_rules: %w[heading-order])
  end

  context "with a previously uploaded document" do
    before do
      activity.document_uploads.attach(io: StringIO.new("Synthetic document"), filename: "evidence.txt", content_type: "text/plain")
      visit new_activities_flow_income_employment_document_upload_path(employment_id: activity)
      verify_page(page, title: upload_title, skip_axe_rules: %w[heading-order])
    end

    it "continues directly to review" do
      click_button I18n.t("activities.document_uploads.new.continue")
      verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: activity.employer_name))
      expect(page).to have_no_text(heading)
    end

    it "requires confirmation after the last document is removed" do
      click_link I18n.t("activities.document_uploads.remove_file")
      expect(page).to have_no_text("evidence.txt")
      click_button I18n.t("activities.document_uploads.new.continue")
      expect(page).to have_selector("[role='dialog'][aria-modal='true']", text: heading)
    end
  end
end
