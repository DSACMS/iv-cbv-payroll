require "rails_helper"

RSpec.describe "Sync delay alerts", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:heading) { I18n.t("application.sync_delay_alert.heading") }
  let(:alerts) { "" }

  around do |example|
    stub_environment_variable("ENABLED_ALERTS", alerts) do
      override_supported_providers([ :argyle ]) do
        e2e = E2e::MockingService.new(server_url: URI(page.server_url))
        e2e.use_recording(recording, &example)
      end
    end
  end

  context "in Income" do
    let(:invitation) { create(:cbv_flow_invitation) }
    let(:recording) { "e2e_cbv_flow_english_argyle_only" }
    let(:account) { create(:payroll_account, :argyle_sync_in_progress, flow: CbvFlow.last) }

    before do
      visit URI(invitation.to_url).request_uri
      verify_page(page, title: I18n.t("cbv.entries.show.header"))
    end

    it "updates the message, heading, and title while polling, then follows a failure redirect" do
      visit cbv_flow_synchronizations_path(user: { account_id: account.aggregator_account_id })
      verify_page(page, title: I18n.t("cbv.synchronizations.show.header"))
      expect(page).to have_no_text(heading)

      account.update!(created_at: 6.minutes.ago)
      verify_page(page, title: heading, wait: 10)
      expect(page).to have_title("#{heading} | #{I18n.t('shared.pilot_name')}", exact: true)
      expect(page).to have_selector("h1", text: heading, count: 1)
      expect(page.evaluate_script("document.activeElement.tagName")).to eq("H1")

      create(:webhook_event, payroll_account: account, event_name: "accounts.updated", event_outcome: "error")
      verify_page(page, title: I18n.t("cbv.synchronization_failures.show.title"), wait: 10)
      expect(page).to have_current_path(cbv_flow_synchronization_failures_path)
      expect(page).to have_no_text(heading)
    end

    context "when manually enabled" do
      let(:alerts) { "sync_delays" }

      it "shows the message on synchronization without showing it on entry" do
        expect(page).to have_no_text(heading)
        visit cbv_flow_synchronizations_path(user: { account_id: account.aggregator_account_id })
        verify_page(page, title: heading)
        expect(page).to have_title("#{heading} | #{I18n.t('shared.pilot_name')}", exact: true)
      end
    end
  end

  context "in Community Engagement" do
    let(:invitation) { create(:activity_flow_invitation) }
    let(:recording) { "e2e_activity_flow" }
    let(:account) { create(:payroll_account, :argyle_sync_in_progress, flow: ActivityFlow.last) }

    before do
      visit activities_flow_start_path(token: invitation.auth_token)
      verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    end

    it "updates the message and title after five minutes without reloading" do
      visit activities_flow_income_synchronizations_path(user: { account_id: account.aggregator_account_id })
      verify_page(page, title: I18n.t("activities.income.synchronizations.show.header"))
      expect(page).to have_no_text(heading)

      account.update!(created_at: 6.minutes.ago)
      verify_page(page, title: heading, wait: 10)
      expect(page).to have_title("#{heading} | #{I18n.t('shared.pilot_name_hr1_full')}", exact: true)
      expect(page).to have_selector("h1", text: heading, count: 1)
      expect(page).to have_text(I18n.t("application.sync_delay_alert.body"))
    end
  end
end
