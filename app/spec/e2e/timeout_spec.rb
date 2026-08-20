require "rails_helper"

RSpec.describe "timeout test", :js, type: :feature do
  include E2e::TestHelpers
  let(:cbv_flow_invitation) do
    create(:cbv_flow_invitation, cbv_applicant_attributes: { case_number: "ABC1234" })
  end

  it 'times out the user and directs them to start again' do
    visit URI(root_url).request_uri
    visit URI(cbv_flow_invitation.to_url).request_uri
    find('[data-cbv-entry-page-target="consentCheckbox"]').click
    click_button I18n.t("cbv.entries.show.continue")
    expect(page).to have_content(I18n.t("cbv.employer_searches.show.header"))
    # Force timeout
    page.driver.browser.execute_script(<<~JS)
      document.getElementById("open-session-modal-button").click()
    JS
    expect(page).to have_selector(".usa-modal__content", visible: true)
    within(".usa-modal__content") do
      verify_page(page, title: I18n.t("session_timeout.modal.heading"))
    end
    click_link I18n.t("session_timeout.modal.end_button")
    verify_page(page, title: I18n.t("session_timeout.page.title"))

    click_link "click here"
    expect(page).to have_content(I18n.t("cbv.entries.show.header"))
    expect(page).not_to have_content(I18n.t("cbv.error_missing_token_html"))
    expect(cbv_flow_invitation.cbv_applicant.reload.case_number).to eq("ABC1234")
  end

  context "when an activity flow times out" do
    include_context "activity_hub"

    it "renders the Emmy timeout copy" do
      visit URI(root_url).request_uri
      visit activities_flow_entry_path(client_agency_id: "sandbox")
      verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))

      page.driver.browser.execute_script(<<~JS)
        document.getElementById("open-session-modal-button").click()
      JS
      expect(page).to have_selector(".usa-modal__content", visible: true)
      click_link I18n.t("session_timeout.modal.end_button")

      verify_page(page, title: I18n.t("pages.home.activity_flow_timeout.header"))
      expect(page).to have_content("Sessions end after 30 minutes of inactivity. This helps keep your information safe.")
      expect(page).to have_content(I18n.t(
        "pages.home.activity_flow_timeout.description",
        agency_name: I18n.t("shared.agency_full_name.sandbox")
      ))
    end
  end
end
