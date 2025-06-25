require "rails_helper"

RSpec.describe "e2e CBV flow test", type: :feature, js: true do
  include E2e::TestHelpers

  let(:cbv_flow_invitation) { create(:cbv_flow_invitation) }

  around do |ex|
    override_supported_providers([ :argyle ]) do
      @e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      @e2e.use_recording("e2e_cbv_flow_english_argyle_only", &ex)
    end
  end

  it "completes the flow for an Argyle employer" do
    raise "Argyle not in supported_providers!" unless Rails.application.config.supported_providers.include?(:argyle)

    # /cbv/entry
    visit URI(root_url).request_uri
    visit URI(cbv_flow_invitation.to_url).request_uri
    verify_page(page, title: I18n.t("cbv.entries.show.header"))
    find("label", text: I18n.t("cbv.entries.show.checkbox.default", agency_full_name: I18n.t("shared.agency_full_name.sandbox"))).click
    click_button I18n.t("cbv.entries.show.continue")

    # /cbv/employer_search
    verify_page(page, title: I18n.t("cbv.employer_searches.show.header"), wait: 10)

    @e2e.replay_modal_callbacks(page.driver.browser) do
      click_button "Paychex"
    end

    @e2e.record_modal_callbacks(page.driver.browser) do
      argyle_container = find("div[id*=\"argyle-link-root\"]")
      page.within(argyle_container) do
        fill_in "username", with: "test_1", wait: 10
        fill_in "password", with: "passgood"
        click_button "Connect"
        fill_in "legacy_mfa_token", with: "8081", wait: 30
        click_button "Continue", wait: 30
      end

      # Wait for Argyle modal to disappear
      find_all("div[id*=\"argyle-link-root\"]", maximum: 0, minimum: nil, wait: 30)
    end

    # /cbv/synchronizations
    verify_page(page, title: I18n.t("cbv.synchronizations.show.header"), wait: 15)

    @e2e.replay_webhooks

    # /cbv/payment_details
    verify_page(page, title: I18n.t("cbv.payment_details.show.header", employer_name: ""), wait: 60)
    fill_in "cbv_flow[additional_information]", with: "Some kind of additional information"
    click_button I18n.t("cbv.payment_details.show.continue")

    # /cbv/add_job
    verify_page(page, title: I18n.t("cbv.add_jobs.show.header"))
    find("label", text: I18n.t("cbv.add_jobs.show.no_radio")).click
    click_button I18n.t("cbv.add_jobs.show.continue")

    # /cbv/summary
    # TODO[FFS-2839]: Fix heading hierarchy on this page
    verify_page(page, title: I18n.t("cbv.summaries.show.header"), skip_axe_rules: %w[heading-order])
    click_on "Continue"

    # /cbv/submits
    verify_page(page, title: I18n.t("cbv.submits.show.page_header"), wait: 10)
    find(:css, "label[for=cbv_flow_consent_to_authorized_use]").click
    click_on "Share my report with CBV"

    # /cbv/success
    verify_page(page, title: I18n.t("cbv.successes.show.header", agency_acronym: ""))
    # TODO: Test PDF rendering by writing it to a file
  end
end
