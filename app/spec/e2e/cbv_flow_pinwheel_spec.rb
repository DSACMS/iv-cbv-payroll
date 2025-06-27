require "rails_helper"

RSpec.describe "e2e CBV flow pinwheel test", type: :feature, js: true do
  include E2e::TestHelpers

  let(:cbv_flow_invitation) { create(:cbv_flow_invitation) }

  around do |ex|
    override_supported_providers([ :pinwheel ]) do
      @e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      @e2e.use_recording("e2e_cbv_flow_english_pinwheel_only", &ex)
    end
  end

  it "completes the flow for an Pinwheel employer" do
    # /cbv/entry
    visit URI(root_url).request_uri
    visit URI(cbv_flow_invitation.to_url).request_uri
    verify_page(page, title: I18n.t("cbv.entries.show.header"))
    find("label", text: I18n.t("cbv.entries.show.checkbox.default", agency_full_name: I18n.t("shared.agency_full_name.sandbox"))).click
    click_button I18n.t("cbv.entries.show.continue")

    # Set `end_user_id` to a known value so the pinwheel webhooks later will match.
    update_cbv_flow_with_deterministic_end_user_id_for_pinwheel(@e2e.cassette_name)

    # /cbv/employer_search
    verify_page(page, title: I18n.t("cbv.employer_searches.show.header"), wait: 10)
    fill_in name: "query", with: "foo"
    click_button I18n.t("cbv.employer_searches.show.search")
    expect(page).to have_content("McKee Foods")

    @e2e.replay_modal_callbacks(page.driver.browser) do
      find("div.usa-card__container", text: "McKee Foods").click_button(I18n.t("cbv.employer_searches.show.select"))
    end

    @e2e.record_modal_callbacks(page.driver.browser) do
      pinwheel_modal = page.find("iframe.pinwheel-modal-show")
      page.within_frame(pinwheel_modal) do
        fill_in "Workday Organization ID", with: "company_good", wait: 20
        click_button "Continue"
        fill_in "Username", with: "user_good", wait: 20
        fill_in "Password", with: "pass_good"
        click_button "Continue"
      end

      # Wait for Pinwheel modal to disappear
      find_all("iframe.pinwheel-modal-show", visible: true, maximum: 0, minimum: nil, wait: 30)
    end

    # /cbv/synchronizations
    verify_page(page, title: I18n.t("cbv.synchronizations.show.header"), wait: 15)

    @e2e.replay_webhooks

    # /cbv/payment_details
    verify_page(page, title: I18n.t("cbv.payment_details.show.header", employer_name: ""), wait: 120)
    fill_in "cbv_flow[additional_information]", with: "Some kind of additional information"
    click_button I18n.t("cbv.payment_details.show.continue")

    # /cbv/add_job
    verify_page(page, title: I18n.t("cbv.add_jobs.show.header"))
    find("label", text: I18n.t("cbv.add_jobs.show.no_radio")).click
    click_button I18n.t("cbv.add_jobs.show.continue")

    # /cbv/summary
    verify_page(page, title: I18n.t("cbv.summaries.show.header"), wait: 10)
    click_on "Continue"

    # /cbv/submits
    verify_page(page, title: I18n.t("cbv.submits.show.page_header"), wait: 10)
    find(:css, "label[for=cbv_flow_consent_to_authorized_use]").click
    click_on "Share my report with CBV"

    # /cbv/success
    verify_page(page, title: I18n.t("cbv.successes.show.header", agency_acronym: ""), wait: 20)
    # TODO: Test PDF rendering by writing it to a file
  end
end
