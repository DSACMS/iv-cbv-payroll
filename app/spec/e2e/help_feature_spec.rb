require "rails_helper"

RSpec.describe "Help Features", type: :feature, js: true do
  include E2e::TestHelpers
  include PinwheelApiHelper

  let(:cbv_flow_invitation) { create(:cbv_flow_invitation) }
  let(:cbv_flow) { create(:cbv_flow, :invited, cbv_flow_invitation: cbv_flow_invitation) }

  before(:all) do
    WebMock.allow_net_connect!
  end

  after(:all) do
    WebMock.disable_net_connect!
  end

  before do
    visit URI(cbv_flow_invitation.to_url).request_uri
    verify_page(page, title: I18n.t("cbv.entries.show.header"))
    find("label", text: I18n.t("cbv.entries.show.checkbox.default", agency_full_name: I18n.t("shared.agency_full_name.sandbox"))).click
    click_button I18n.t("cbv.entries.show.continue")
  end

  describe "Help Banner" do
    it "shows help banner when help=true in URL" do
      visit cbv_flow_employer_search_path(help: true)
      expect(page).to have_selector("#help-alert")
      expect(page).to have_content(I18n.t("help.alert.heading"))
    end

    it "does not show help banner without help parameter" do
      visit cbv_flow_employer_search_path
      expect(page).not_to have_selector("#help-alert")
    end
  end

  describe "Help Modal" do
    it "opens help modal when clicking link in help banner" do
      visit cbv_flow_employer_search_path(help: true)

      within("#help-alert") do
        click_link I18n.t("help.alert.help_options")
      end

      # Wait for modal and iframe to be visible
      expect(page).to have_selector("#help-modal", visible: true, wait: 5)
      expect(page).to have_selector("iframe#help-iframe", visible: true, wait: 5)
    end

    it "displays correct content in help modal" do
      visit cbv_flow_employer_search_path(help: true)
      click_link I18n.t("help.alert.help_options")

      # Wait for iframe to load
      expect(page).to have_selector("iframe#help-iframe", visible: true, wait: 5)

      within_frame("help-iframe") do
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
        expect(feedback_link[:href]).to eq(SiteConfig.current.caseworker_feedback_form)
        expect(feedback_link[:target]).to eq("_blank")
      end
    end

    it "can navigate between help topics" do
      visit cbv_flow_employer_search_path(help: true)
      click_link I18n.t("help.alert.help_options")

      # Wait for iframe to load
      expect(page).to have_selector("iframe#help-iframe", visible: true, wait: 5)

      within_frame("help-iframe") do
        click_link I18n.t("help.index.username")
        verify_page(page, title: I18n.t("help.show.username.title"))

        click_link I18n.t("help.show.go_back")
        verify_page(page, title: I18n.t("help.index.title"))
      end
    end

    it "closes help modal when clicking close button" do
      visit cbv_flow_employer_search_path(help: true)
      click_link I18n.t("help.alert.help_options")

      # Wait for modal to be visible
      expect(page).to have_selector("#help-modal", visible: true, wait: 5)

      find("button[aria-label='Close this window']").click
      expect(page).not_to have_selector("#help-modal", visible: true)
    end
  end
end
