require "rails_helper"

RSpec.describe "Help Features", type: :feature, js: true do
  include E2e::TestHelpers
  include PinwheelApiHelper
  include ApplicationHelper

  let(:cbv_flow_invitation) { create(:cbv_flow_invitation) }
  let(:cbv_flow) { create(:cbv_flow, :invited, cbv_flow_invitation: cbv_flow_invitation) }

  before(:all) do
    WebMock.allow_net_connect!
  end

  after(:all) do
    WebMock.disable_net_connect!
  end

  context "When in the applicant flow" do
    before do
      visit URI(cbv_flow_invitation.to_url).request_uri
      find("label", text: I18n.t("cbv.entries.show.checkbox_large_text.default", agency_full_name: I18n.t("shared.agency_full_name.sandbox"))).click
      click_button I18n.t("cbv.entries.show.continue")
    end

    it "opens help modal when clicking link in help banner" do
      visit cbv_flow_employer_search_path(help: true)
      click_link "Help"

      expect(page).to have_selector("#help-modal", visible: true, wait: 5)
      expect(page).to have_selector(".usa-modal__content", visible: true, wait: 5)
    end

    it "displays correct content in the help modal" do
      visit cbv_flow_employer_search_path(help: true)
      click_link "Help"

      expect(page).to have_selector(".usa-modal__content", visible: true, wait: 5)

      within(".usa-modal__content") do
        expect(page).to have_content(I18n.t("help.index.select_prompt"))

        # Verify all help topic buttons are present
        expect(page).to have_link(I18n.t("help.index.username"))
        expect(page).to have_link(I18n.t("help.index.password"))
        expect(page).to have_link(I18n.t("help.index.company_id"))
        expect(page).to have_link(I18n.t("help.index.employer"))
        expect(page).to have_link(I18n.t("help.index.provider"))
        expect(page).to have_link(I18n.t("help.index.credentials"))

        # Verify feedback link opens in new tab with correct URL
        feedback_link = find_link(I18n.t("help.index.feedback"))
        expect(feedback_link[:href]).to eq(ApplicationHelper::APPLICANT_FEEDBACK_FORM)
        expect(feedback_link[:target]).to eq("_blank")
      end
    end


    it "can navigate between help topics" do
      visit cbv_flow_employer_search_path(help: true)
      click_link "Help"

      expect(page).to have_selector(".usa-modal__content", visible: true, wait: 5)
    end

    it "closes help modal when clicking close button" do
      visit cbv_flow_employer_search_path(help: true)
      click_link "Help"

      # Wait for modal to be visible
      expect(page).to have_selector("#help-modal", visible: true, wait: 5)

      find("button[aria-label='Close this window']").click
      expect(page).not_to have_selector("#help-modal", visible: true)
    end
  end

  context "When in the caseworker flow" do
    it "displays correct content in the help modal" do
      visit caseworker_dashboard_path(client_agency_id: "sandbox")
      click_link "Help"

      expect(page).to have_selector(".usa-modal__content", visible: true, wait: 5)

      within(".usa-modal__content") do
        expect(page).to have_content(I18n.t("help.index.select_prompt"))

        # Verify all help topic buttons are present
        expect(page).to have_link(I18n.t("help.index.username"))
        expect(page).to have_link(I18n.t("help.index.password"))
        expect(page).to have_link(I18n.t("help.index.company_id"))
        expect(page).to have_link(I18n.t("help.index.employer"))
        expect(page).to have_link(I18n.t("help.index.provider"))
        expect(page).to have_link(I18n.t("help.index.credentials"))

        # Verify feedback link opens in new tab with correct URL
        feedback_link = find_link(I18n.t("help.index.feedback"))
        expect(feedback_link[:href]).to eq("https://docs.google.com/forms/d/e/1FAIpQLSfrUiz0oWE5jbXjPfl-idQQGPgxKplqFtcKq08UOhTaEa2k6A/viewform")
        expect(feedback_link[:target]).to eq("_blank")
      end
    end
  end
end
