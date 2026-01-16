require "rails_helper"

RSpec.describe 'e2e Activity Hub flow test', type: :feature, js: true do
  include E2e::TestHelpers
  include_context "activity_hub"
  around do |ex|
    override_supported_providers([ :argyle ]) do
      @e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      @e2e.use_recording("e2e_cbv_flow_english_argyle_only", &ex)
    end
  end

  it "completes the generic flow for all activities" do
    visit URI(root_url).request_uri

    visit activities_flow_entry_path(client_agency_id: "sandbox") # This would normally be inferred
    verify_page(page, title: I18n.t("activities.entry.title"))
    find("label", text: I18n.t("activities.entry.consent", agency_name: I18n.t("shared.agency_full_name.sandbox"))).click
    click_button I18n.t("activities.entry.continue")

    verify_page(page, title: I18n.t("activities.hub.title"))

    # Add an Income activity
    click_button I18n.t("activities.income.add")
    verify_page(page, title: I18n.t("cbv.employer_searches.show.activity_flow.header"))
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
    # /activities/income/synchronizations
    verify_page(page, title: I18n.t("cbv.synchronizations.show.activity_flow.header"), wait: 15)
    # /activities/income/payment_details
    @e2e.replay_webhooks
    verify_page(page, title: I18n.t("cbv.payment_details.show.header", employer_name: ""), wait: 60)
    fill_in "activity_flow[additional_information]", with: "Some kind of additional information"
    click_button I18n.t("cbv.payment_details.show.continue")

    # Add a Volunteering activity
    click_button I18n.t("activities.volunteering.add")
    verify_page(page, title: I18n.t("activities.volunteering.title"))
    fill_in I18n.t("activities.volunteering.organization_name"), with: "Helping Hands"
    fill_in I18n.t("activities.volunteering.hours"), with: "20"
    fill_in I18n.t("activities.volunteering.date"), with: Date.current.strftime("%m/%d/%Y")
    click_button I18n.t("activities.volunteering.add")
    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_content I18n.t("activities.volunteering.add")

    # Add a Job Training activity
    click_button I18n.t("activities.job_training.add")
    verify_page(page, title: I18n.t("activities.job_training.title"))
    fill_in I18n.t("activities.job_training.program_name"), with: "Resume Workshop"
    fill_in I18n.t("activities.job_training.organization_address"), with: "123 Main St, Baton Rouge, LA"
    fill_in I18n.t("activities.job_training.hours"), with: "6"
    click_button I18n.t("activities.job_training.add")
    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_content I18n.t("activities.job_training.add")

    # Verify that the hub has the Volunteering activity
    expect(page).to have_content I18n.t("activities.hub.title")
    expect(page).to have_content "Helping Hands"
    expect(page).to have_content Date.current
    expect(page).to have_content "20"
    # Verify that the hub has the Job Training activity
    expect(page).to have_content "Resume Workshop"
    expect(page).to have_content "123 Main St, Baton Rouge, LA"
    expect(page).to have_content "6"

    click_button I18n.t("activities.hub.continue")
    verify_page(page, title: I18n.t("activities.summary.title"))
    expect(page).to have_content "Helping Hands"
    expect(page).to have_content "Resume Workshop"

    click_button I18n.t("activities.summary.submit")
    verify_page(page, title: I18n.t("activities.submit.title"))
    find("label[for='activity_flow_consent_to_submit']").click
    click_button I18n.t("activities.submit.confirm")
    verify_page(page, title: I18n.t("activities.success.title", agency_name: I18n.t("shared.agency_full_name.sandbox")))
    expect(page).to have_content I18n.t("activities.success.completed_at")
  end

  it "blocks activity hub access when not enabled" do
    stub_environment_variable("ACTIVITY_HUB_ENABLED", nil) do
      visit activities_flow_root_path
      expect(page).to have_content(I18n.t("pages.home.header"))
      visit new_activities_flow_volunteering_path
      expect(page).to have_content(I18n.t("pages.home.header"))
    end
  end
end
