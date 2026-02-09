require "rails_helper"

RSpec.describe 'e2e Activity Hub flow test', :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  around do |ex|
    override_supported_providers([ :argyle ]) do
      @e2e = E2e::MockingService.new(server_url: URI(page.server_url))
      @e2e.use_recording("e2e_activity_flow", &ex)
    end
  end

  it "completes the generic flow for all self-attestation activities" do
    visit URI(root_url).request_uri

    visit activities_flow_entry_path(client_agency_id: "sandbox") # This would normally be inferred
    verify_page(page, title: I18n.t("activities.entry.title"))
    find("label", text: I18n.t("activities.entry.consent", agency_name: I18n.t("shared.agency_full_name.sandbox"))).click
    click_button I18n.t("activities.entry.continue")

    verify_page(page, title: I18n.t("activities.hub.title"))

    # Add a Community Service activity
    within("[data-activity-type='community_service']") do
      click_button I18n.t("activities.hub.add")
    end
    verify_page(page, title: I18n.t("activities.community_service.title"))
    fill_in I18n.t("activities.community_service.organization_name"), with: "Helping Hands"
    fill_in I18n.t("activities.community_service.hours"), with: "20"
    fill_in I18n.t("activities.community_service.date"), with: (Date.current.beginning_of_month - 1.day).strftime("%m/%d/%Y")
    click_button I18n.t("activities.community_service.add")
    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_content "Helping Hands"

    # Add a Work Programs activity
    within("[data-activity-type='work_programs']") do
      click_button I18n.t("activities.hub.add")
    end
    verify_page(page, title: I18n.t("activities.work_programs.title"))
    fill_in I18n.t("activities.work_programs.program_name"), with: "Resume Workshop"
    fill_in I18n.t("activities.work_programs.organization_address"), with: "123 Main St, Baton Rouge, LA"
    fill_in I18n.t("activities.work_programs.hours"), with: "6"
    click_button I18n.t("activities.work_programs.add")
    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_content "Resume Workshop"

    # Verify that the hub has the Community Service activity
    expect(page).to have_content I18n.t("activities.hub.title")
    expect(page).to have_content "Helping Hands"
    expect(page).to have_content I18n.t("activities.hub.cards.hours", count: 20)

    # Verify that the hub has the Work Programs activity
    expect(page).to have_content "Resume Workshop"

    click_button I18n.t("activities.hub.review_and_submit")
    verify_page(page, title: I18n.t("activities.summary.title"))
    expect(page).to have_content "Helping Hands"
    expect(page).to have_content "Resume Workshop"

    # /activities/summary
    click_button I18n.t("activities.summary.submit", agency_name: I18n.t("shared.agency_full_name.sandbox"))
    verify_page(page, title: I18n.t("activities.submit.title"))
    find("label[for='activity_flow_consent_to_submit']").click
    click_button I18n.t("activities.submit.confirm")

    # /activities/success
    verify_page(page, title: I18n.t("activities.success.show.title", agency_acronym: I18n.t("shared.agency_acronym.sandbox")))
    expect(page).to have_content I18n.t("activities.success.show.download_pdf")
  end

  it "completes the generic flow for the income activity" do
    visit URI(root_url).request_uri

    visit activities_flow_entry_path(client_agency_id: "sandbox") # This would normally be inferred
    verify_page(page, title: I18n.t("activities.entry.title"))
    find("label", text: I18n.t("activities.entry.consent", agency_name: I18n.t("shared.agency_full_name.sandbox"))).click
    click_button I18n.t("activities.entry.continue")

    verify_page(page, title: I18n.t("activities.hub.title"))

    # Add an Employment activity
    within("[data-activity-type='employment']") do
      click_button I18n.t("activities.hub.add")
    end
    verify_page(page, title: I18n.t("cbv.employer_searches.show.activity_flow.header"))
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
    # /activities/income/synchronizations
    verify_page(page, title: I18n.t("cbv.synchronizations.show.activity_flow.header"), wait: 15)
    # /activities/income/payment_details
    @e2e.replay_webhooks
    verify_page(page, title: I18n.t("cbv.payment_details.show.activity_flow.header", employer_name: ""), wait: 60)
    fill_in "payroll_account[additional_information]",
      with: "Some kind of additional information"
    click_button I18n.t("cbv.payment_details.show.continue")
    verify_page(page, title: I18n.t("activities.hub.title"))

    click_button I18n.t("activities.hub.review_and_submit")
    verify_page(page, title: I18n.t("activities.summary.title"))

    # /activities/summary
    click_button I18n.t("activities.summary.submit", agency_name: I18n.t("shared.agency_full_name.sandbox"))
    verify_page(page, title: I18n.t("activities.submit.title"))
    find("label[for='activity_flow_consent_to_submit']").click
    click_button I18n.t("activities.submit.confirm")

    # /activities/success
    verify_page(page, title: I18n.t("activities.success.show.title", agency_acronym: I18n.t("shared.agency_acronym.sandbox")))
    expect(page).to have_content I18n.t("activities.success.show.download_pdf")
  end

  it "completes the generic flow for the education activity" do
    visit URI(root_url).request_uri

    visit activities_flow_entry_path(client_agency_id: "sandbox") # This would normally be inferred
    verify_page(page, title: I18n.t("activities.entry.title"))
    find("label", text: I18n.t("activities.entry.consent", agency_name: I18n.t("shared.agency_full_name.sandbox"))).click
    click_button I18n.t("activities.entry.continue")

    verify_page(page, title: I18n.t("activities.hub.title"))

    # Add an Education activity
    within("[data-activity-type='education']") do
      click_button I18n.t("activities.hub.add")
    end
    performing_active_jobs do
      click_button I18n.t("activities.education.new.continue")
      verify_page(page, title: I18n.t("activities.education.show.header")) # /activities/education/123 (loading page)
    end
    verify_page(page, title: I18n.t("activities.education.edit.header"), wait: 10) # /activities/education/123/edit (show page)
    find("a", text: I18n.t("activities.education.edit.no_records_found.return_button")).click

    click_button I18n.t("activities.hub.review_and_submit")
    verify_page(page, title: I18n.t("activities.summary.title"))

    # /activities/summary
    click_button I18n.t("activities.summary.submit", agency_name: I18n.t("shared.agency_full_name.sandbox"))
    verify_page(page, title: I18n.t("activities.submit.title"))
    find("label[for='activity_flow_consent_to_submit']").click
    click_button I18n.t("activities.submit.confirm")

    # /activities/success
    verify_page(page, title: I18n.t("activities.success.show.title", agency_acronym: I18n.t("shared.agency_acronym.sandbox")))
    expect(page).to have_content I18n.t("activities.success.show.download_pdf")
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
