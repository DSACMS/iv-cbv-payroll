require "rails_helper"

RSpec.describe "e2e CBV flow test", :js, type: :feature do
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
    find('[data-cbv-entry-page-target="consentCheckbox"]').click
    click_button I18n.t("cbv.entries.show.continue")

    # /cbv/employer_search
    verify_page(page, title: I18n.t("cbv.employer_searches.show.header"), wait: 10)

    @e2e.replay_modal_callbacks(page.driver.browser) do
      click_button "Paychex"
    end

    @e2e.record_modal_callbacks(page.driver.browser) do
      argyle_container = find("div[id*=\"argyle-link-root\"]", visible: :all)
      page.within(argyle_container.shadow_root) do
        find('[name="username"]', wait: 10).fill_in(with: "test_1")
        find('[name="password"]').fill_in(with: "passgood")
        find('[data-hook="connect-button"]').click
        wait_for_idle(page)
        find('[name="legacy_mfa_token"]', wait: 30).fill_in(with: "8081")
        wait_for_idle(page)
        find('[data-hook="connect-button"]', wait: 30).click
      end

      # Wait for Argyle modal to disappear
      find_all("div[id*=\"argyle-link-root\"]", visible: :all, maximum: 0, minimum: nil, wait: 30)
    end

    # /cbv/synchronizations
    verify_page(page, title: I18n.t("cbv.synchronizations.show.header"), wait: 15)

    @e2e.replay_webhooks

    # /cbv/payment_details
    verify_page(page, title: I18n.t("cbv.payment_details.show.header", employer_name: ""), wait: 60)
    fill_in "payroll_account[additional_information]",
      with: "Some kind of additional information"
    click_button I18n.t("cbv.payment_details.show.continue")

    # /cbv/add_job
    verify_page(page, title: I18n.t("cbv.add_jobs.show.header"))
    find("label", text: I18n.t("cbv.add_jobs.show.radio_no")).click
    click_on(I18n.t("continue"))

    # /cbv/other_jobs
    verify_page(page, title: I18n.t("cbv.other_jobs.show.header"), wait: 10, skip_axe_rules: %w[heading-order])
    find("label", text: I18n.t("cbv.other_jobs.show.radio_yes", agency_acronym: I18n.t("shared.agency_acronym.sandbox"))).click
    click_on "Continue"

    # /cbv/summary
    verify_page(page, title: I18n.t("cbv.summaries.show.header"))
    click_on "Continue"

    # /cbv/submits
    verify_page(page, title: I18n.t("cbv.submits.show.page_header"), wait: 10)
    find(:css, "label[for=cbv_flow_consent_to_authorized_use]").click
    click_on I18n.t("cbv.submits.show.share_report_button", agency_acronym: I18n.t("shared.agency_acronym.sandbox"))

    # /cbv/success
    verify_page(page, title: I18n.t("cbv.successes.show.header", agency_acronym: I18n.t("shared.agency_acronym.sandbox")))
    # TODO: Test PDF rendering by writing it to a file
  end
end
