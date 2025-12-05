require "rails_helper"

RSpec.describe 'e2e Activity Hub flow test', type: :feature, js: true do
  include E2e::TestHelpers

  it "completes the flow for all activities" do
    visit URI(root_url).request_uri

    visit activities_flow_entry_path
    verify_page(page, title: I18n.t("activities.entry.title"))
    click_button I18n.t("activities.entry.continue")

    verify_page(page, title: I18n.t("activities.hub.title"))

    # Add a Volunteering activity
    click_button I18n.t("activities.volunteering.add")
    verify_page(page, title: I18n.t("activities.volunteering.title"))
    fill_in I18n.t("activities.volunteering.organization_name"), with: "Helping Hands"
    fill_in I18n.t("activities.volunteering.hours"), with: "20"
    fill_in I18n.t("activities.volunteering.date"), with: "10/10/1990"
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
    expect(page).to have_content "1990-10-10"
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
    verify_page(page, title: I18n.t("activities.success.title"))
    expect(page).to have_content I18n.t("activities.success.completed_at")
  end

  it "is redirects to the normal flow in non-development environments" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    visit activities_flow_root_path
    expect(page).to have_content(I18n.t("pages.home.header"))
    visit new_activities_flow_volunteering_path
    expect(page).to have_content(I18n.t("pages.home.header"))
  end
end
