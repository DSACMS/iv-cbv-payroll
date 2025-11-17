require "rails_helper"

RSpec.describe 'e2e Activity Hub flow test', type: :feature, js: true do
  include E2e::TestHelpers

  it "completes the flow for an Argyle employer" do
    # /cbv/entry
    visit URI(root_url).request_uri
    visit activities_flow_root_path
    verify_page(page, title: "Activity Hub")
    click_button "Add Volunteering Activity"
    verify_page(page, title: "Volunteering")
    fill_in "Organization name", with: "Helping Hands"
    fill_in "Hours", with: "20"
    fill_in "Date", with: "10/10/1990"
    click_button "Add Volunteering Activity"
    verify_page(page, title: "Activity Hub")
    expect(page).to have_content "Volunteering activity was successfully created."

    expect(page).to have_content "Volunteering Activities"
    expect(page).to have_content "Helping Hands"
    expect(page).to have_content "1990-10-10"
    expect(page).to have_content "20"
  end
end
