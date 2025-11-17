require "rails_helper"

RSpec.describe 'e2e Activity Hub flow test', type: :feature, js: true do
  include E2e::TestHelpers

  it "completes the flow for an Argyle employer" do
    # /cbv/entry
    visit URI(root_url).request_uri
    visit activities_flow_root_path
    verify_page(page, title: "Activity Hub")
    click_button "Add Income Source"
    # verify_page(page, title: "Activity Hub")

    # # /cbv/employer_search
    # verify_page(page, title: I18n.t("cbv.employer_searches.show.header"), wait: 10)
    #
    # @e2e.replay_modal_callbacks(page.driver.browser) do
    #   click_button "Paychex"
    # end
    #
    # @e2e.record_modal_callbacks(page.driver.browser) do
    #   argyle_container = find("div[id*=\"argyle-link-root\"]")
    #   page.within(argyle_container) do
    #     fill_in "username", with: "test_1", wait: 10
    #     fill_in "password", with: "passgood"
    #     click_button "Connect"
    #     fill_in "legacy_mfa_token", with: "8081", wait: 30
    #     click_button "Continue", wait: 30
    #   end
    #
    #   # Wait for Argyle modal to disappear
    #   find_all("div[id*=\"argyle-link-root\"]", maximum: 0, minimum: nil, wait: 30)
    # end
    #
    # # /cbv/synchronizations
    # verify_page(page, title: I18n.t("cbv.synchronizations.show.header"), wait: 15)
    #
    # @e2e.replay_webhooks
    #
    # # /cbv/payment_details
    # verify_page(page, title: I18n.t("cbv.payment_details.show.header", employer_name: ""), wait: 60)
    # fill_in "cbv_flow[additional_information]", with: "Some kind of additional information"
    # click_button I18n.t("cbv.payment_details.show.continue")
    #
    # # /cbv/add_job
    # verify_page(page, title: I18n.t("cbv.add_jobs.show.header"))
    # find("label", text: I18n.t("cbv.add_jobs.show.radio_no")).click
    # click_on(I18n.t("continue"))
    #
    # # /cbv/other_jobs
    # verify_page(page, title: I18n.t("cbv.other_jobs.show.header"), wait: 10, skip_axe_rules: %w[heading-order])
    # find("label", text: I18n.t("cbv.other_jobs.show.radio_yes", agency_acronym: I18n.t("shared.agency_acronym.sandbox"))).click
    # click_on "Continue"
    #
    # # /cbv/summary
    # verify_page(page, title: I18n.t("cbv.summaries.show.header"))
    # click_on "Continue"
  end
end
