require "rails_helper"

RSpec.describe "Help Features", :js, type: :feature do
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
      verify_page(page, title: I18n.t("cbv.entries.show.header"))
      find("label", text: I18n.t("cbv.entries.show.checkbox_large_text.default", agency_full_name: I18n.t("shared.agency_full_name.sandbox"))).click
      click_button I18n.t("cbv.entries.show.continue")
    end

    it "opens help modal when clicking link in help banner" do
      visit cbv_flow_employer_search_path
      click_link "Help"

      expect(page).to have_selector(".usa-modal__content", visible: true)
    end

    it "displays correct content in the help modal" do
      visit cbv_flow_employer_search_path
      click_link "Help"

      expect(page).to have_selector(".usa-modal__content", visible: true)

      within(".usa-modal__content") do
        verify_page(page, title: I18n.t("help.index.title"))
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
      visit cbv_flow_employer_search_path
      click_link "Help"

      expect(page).to have_selector(".usa-modal__content", visible: true)

      within(".usa-modal__content") do
        click_link I18n.t("help.index.username")
        verify_page(page, title: I18n.t("help.show.username.title"))

        click_link I18n.t("help.show.go_back")
        verify_page(page, title: I18n.t("help.index.title"))
      end
    end

    it "closes help modal when clicking close button" do
      visit cbv_flow_employer_search_path
      click_link "Help"

      # Wait for modal to be visible
      expect(page).to have_selector(".usa-modal__content", visible: true)

      find("button[aria-label='Close this window']").click
      expect(page).not_to have_selector(".usa-modal__content", visible: true)
    end
  end
end
