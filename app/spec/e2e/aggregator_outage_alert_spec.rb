require "rails_helper"

RSpec.describe "Aggregator outage alerts", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:heading) { I18n.t("application.aggregator_outage_alert.heading") }

  around do |example|
    stub_environment_variable("ENABLED_ALERTS", "aggregator_outage") do
      override_supported_providers([ :argyle ]) do
        e2e = E2e::MockingService.new(server_url: URI(page.server_url))
        e2e.use_recording(recording, &example)
      end
    end
  end

  context "in Income" do
    let(:invitation) { create(:cbv_flow_invitation) }
    let(:recording) { "e2e_cbv_flow_english_argyle_only" }

    before do
      visit URI(invitation.to_url).request_uri
      verify_page(page, title: I18n.t("cbv.entries.show.header"))
    end

    it "shows the alert only after reaching employer search" do
      expect(page).to have_no_text(heading)
      find('[data-cbv-entry-page-target="consentCheckbox"]').click
      click_button I18n.t("cbv.entries.show.continue")
      verify_page(page, title: I18n.t("cbv.employer_searches.show.header"))
      expect(page).to have_selector(".usa-alert--warning", text: heading)
      expect(page).to have_text(I18n.t("application.aggregator_outage_alert.income_body"))
      expect(page).to have_no_link(I18n.t("application.aggregator_outage_alert.manual_entry"))
    end
  end

  context "in Community Engagement" do
    let(:invitation) { create(:activity_flow_invitation) }
    let(:recording) { "e2e_activity_flow" }

    before do
      visit activities_flow_start_path(token: invitation.auth_token)
      verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    end

    it "offers a working manual-entry link only on employer search" do
      expect(page).to have_no_text(heading)
      visit activities_flow_income_employer_search_path
      verify_page(page, title: I18n.t("activities.income.employer_searches.show.header"))
      expect(page).to have_selector(".usa-alert--warning", text: heading)
      click_link I18n.t("application.aggregator_outage_alert.manual_entry")
      verify_page(page, title: I18n.t("activities.employment_info.title"))
      expect(page).to have_current_path(new_activities_flow_income_employment_path)
      expect(page).to have_no_text(heading)
    end
  end
end
