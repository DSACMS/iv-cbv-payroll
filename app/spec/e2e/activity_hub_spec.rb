require "rails_helper"

RSpec.describe 'e2e Activity Hub flow test', type: :feature, js: true do
  include E2e::TestHelpers

  it "completes the flow for all activities" do
    visit URI(root_url).request_uri
    visit activities_flow_root_path
    verify_page(page, title: I18n.t("activities.hub.title"))
    click_button I18n.t("activities.volunteering.add")
    verify_page(page, title: I18n.t("activities.volunteering.title"))
    fill_in I18n.t("activities.volunteering.organization_name"), with: "Helping Hands"
    fill_in I18n.t("activities.volunteering.hours"), with: "20"
    fill_in I18n.t("activities.volunteering.date"), with: "10/10/1990"
    click_button I18n.t("activities.volunteering.add")
    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_content I18n.t("activities.volunteering.add")

    expect(page).to have_content I18n.t("activities.hub.title")
    expect(page).to have_content "Helping Hands"
    expect(page).to have_content "1990-10-10"
    expect(page).to have_content "20"
  end

  it "is redirects to the normal flow in non-development environments" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    visit activities_flow_root_path
    expect(page).to have_content(I18n.t("pages.home.header"))
    visit new_activities_flow_volunteering_path
    expect(page).to have_content(I18n.t("pages.home.header"))
  end
end
