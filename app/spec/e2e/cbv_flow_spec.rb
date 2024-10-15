require "rails_helper"

RSpec.describe "e2e CBV flow test", type: :feature, js: true do
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
    capybara_server_url = URI(page.server_url)
    @ngrok.start_tunnel(capybara_server_url.port)
    puts "Found ngrok tunnel at #{@ngrok.tunnel_url}!"
    @subscription_id = PinwheelWebhookManager.new.create_subscription_if_necessary(
      @ngrok.tunnel_url,
      ENV["USER"]
    )
  end

  after(:all, js: true) do
    if @subscription_id
      puts "[PINWHEEL] Deleting webhook subscription id: #{@subscription_id}"
      PinwheelService.new("sandbox").delete_webhook_subscription(@subscription_id)
    end

    # TODO: Remove these when we stub out Pinwheel usage:
    page.quit
    WebMock.disable_net_connect!
  end

  shared_examples "proceeding through the flow normally" do
    it "completes the flow" do
      # /cbv/entry
      visit URI(cbv_flow_invitation.to_url).request_uri
      verify_page(page, title: I18n.t("cbv.entries.show.header.default", agency_acronym: "CBV"))
      click_button I18n.t("cbv.entries.show.get_started")

      # /cbv/agreement
      verify_page(page, title: I18n.t("cbv.agreements.show.header"))
      find("label", text: I18n.t("cbv.agreements.show.checkbox.default", agency_full_name: I18n.t("shared.agency_full_name.sandbox"))).click
      click_button I18n.t("cbv.agreements.show.continue")

      # /cbv/employer_search
      verify_page(page, title: I18n.t("cbv.employer_searches.show.header"))
      fill_in name: "query", with: "foo"
      click_button I18n.t("cbv.employer_searches.show.search")
      expect(page).to have_content("McKee Foods")
      find("div.usa-card__container", text: "McKee Foods").click_button(I18n.t("cbv.employer_searches.show.select"))

      # Pinwheel modal
      pinwheel_modal = page.find("iframe.pinwheel-modal-show")
      page.within_frame(pinwheel_modal) do
        if I18n.locale == :en
          fill_in "Username", with: "user_good", wait: 10
          fill_in "Workday Password", with: "pass_good"
          click_button "Continue"
        elsif I18n.locale == :es
          fill_in "Nombre de usuario", with: "user_good", wait: 10
          fill_in "Contraseña de Workday", with: "pass_good"
          click_button "Continuar"
        else
          raise "Unknown locale: #{I18n.locale}"
        end
      end

      # /cbv/synchronizations
      verify_page(page, title: I18n.t("cbv.synchronizations.show.header"), wait: 15)

      # All the pinwheel webhooks occur here!

      # /cbv/payment_details
      verify_page(page, title: I18n.t("cbv.payment_details.show.header", employer_name: "Acme Corporation"), wait: 60)
      fill_in "cbv_flow[additional_information]", with: "Some kind of additional information"
      click_button I18n.t("cbv.payment_details.show.continue")

      # /cbv/add_job
      verify_page(page, title: I18n.t("cbv.add_jobs.show.header"))
      find("label", text: I18n.t("cbv.add_jobs.show.no_radio")).click
      click_button I18n.t("cbv.add_jobs.show.continue")

      # /cbv/summary
      verify_page(page, title: I18n.t("cbv.summaries.show.header"))
      find(:css, "label[for=cbv_flow_consent_to_authorized_use]").click
      click_button I18n.t("cbv.summaries.show.send_report", agency_acronym: "CBV")

      # TODO: Test PDF rendering by writing it to a file
    end
  end

  context "in english" do
    it_behaves_like "proceeding through the flow normally"
  end

  context "in spanish" do
    before do
      cbv_flow_invitation.update(language: "es")
    end

    around do |ex|
      I18n.with_locale("es", &ex)
    end

    it_behaves_like "proceeding through the flow normally"
  end
end
