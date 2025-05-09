require "rails_helper"

# flip this to "all" if you need to record a new interaction
# to run these tests with record: :all, make sure you have a .env.test.local with PINWHEEL_API_TOKEN_SANDBOX, then you can run this test via running
# to run these tests at all,
# explicitly via rubymine, or RUN_E2E_TESTS=1 bundle exec rspec spec/e2e/cbb_flow_spec.rb
RECORD_OPTION = :none

RSpec.describe "e2e CBV flow test", type: :feature, js: true, vcr: { record: RECORD_OPTION, name: "e2e_cbv_flow_english" } do
  include E2eTestHelpers
  include_context "with_ngrok_tunnel"

  let(:cbv_flow_invitation) { create(:cbv_flow_invitation) }
  before(:all, js: true) do
    unless ENV.fetch("PINWHEEL_API_TOKEN_SANDBOX", "").length == 64
      raise "You need to set a PINWHEEL_API_TOKEN_SANDBOX in .env.test.local in order for this test to succeed"
    end
    unless ENV.fetch("USER", "").length > 0
      raise "You need to set a USER environment variable"
    end

    # TODO: Remove this when we stub out Pinwheel usage:
    # (We will have to allow access to the capybara server URL.)
    WebMock.allow_net_connect!
    # Register Ngrok with Pinwheel
    VCR.use_cassette("e2e_cbv_flow_english", record: RECORD_OPTION) do
      capybara_server_url = URI(page.server_url)
      @ngrok.start_tunnel(capybara_server_url.port)
      puts "Found ngrok tunnel at #{@ngrok.tunnel_url}!"
      @subscription_id = PinwheelWebhookManager.new.create_subscription_if_necessary(
        @ngrok.tunnel_url,
        ENV["USER"]
      )
    end if RECORD_OPTION == :all
  end

  after(:all, js: true) do
    if @subscription_id && RECORD_OPTION == :all
      VCR.use_cassette("e2e_cbv_flow_english", record: :all) do
        puts "[PINWHEEL] Deleting webhook subscription id: #{@subscription_id}"
        Aggregators::Sdk::PinwheelService.new("sandbox").delete_webhook_subscription(@subscription_id)
      end
    end
  end

  it "completes the flow" do
    # /cbv/entry
    mock_cbv_flow_responses

    visit URI(root_url).request_uri
    visit URI(cbv_flow_invitation.to_url).request_uri
    verify_page(page, title: I18n.t("cbv.entries.show.header"))
    find("label", text: I18n.t("cbv.entries.show.checkbox.default", agency_full_name: I18n.t("shared.agency_full_name.sandbox"))).click
    click_button I18n.t("cbv.entries.show.continue")

    # /cbv/employer_search
    verify_page(page, title: I18n.t("cbv.employer_searches.show.header"), wait: 10)
    fill_in name: "query", with: "foo"
    click_button I18n.t("cbv.employer_searches.show.search")
    expect(page).to have_content("McKee Foods")
    find("div.usa-card__container", text: "McKee Foods").click_button(I18n.t("cbv.employer_searches.show.select"))


    # Pinwheel modal
    pinwheel_modal = page.find("iframe.pinwheel-modal-show")
    page.within_frame(pinwheel_modal) do
      fill_in "Workday Organization ID", with: "company_good", wait: 10
      click_button "Continue"
      fill_in "Username", with: "user_good", wait: 10
      fill_in "Password", with: "pass_good", wait: 10
      simulate_next_step_and_webhooks
      click_button "Continue"
    end

    # /cbv/synchronizations
    verify_page(page, title: I18n.t("cbv.synchronizations.show.header"), wait: 15)

    # All the pinwheel webhooks occur here!
    # TODO bring back the rest of this flow via sliding more webhooks in

    # /cbv/payment_details
    # verify_page(page, title: I18n.t("cbv.payment_details.show.header", employer_name: "Acme Corporation"), wait: 60)
    # fill_in "cbv_flow[additional_information]", with: "Some kind of additional information"
    # click_button I18n.t("cbv.payment_details.show.continue")

    # /cbv/add_job
    # verify_page(page, title: I18n.t("cbv.add_jobs.show.header"))
    # find("label", text: I18n.t("cbv.add_jobs.show.no_radio")).click
    # click_button I18n.t("cbv.add_jobs.show.continue")
    #
    # # /cbv/summary
    # verify_page(page, title: I18n.t("cbv.summaries.show.header"))
    # click_on "Continue"
    # find(:css, "label[for=cbv_flow_consent_to_authorized_use]").click
    # click_on "Share my report with CBV"

    # TODO: Test PDF rendering by writing it to a file
  end
end
