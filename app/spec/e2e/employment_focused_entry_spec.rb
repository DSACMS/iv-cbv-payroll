require "rails_helper"

RSpec.describe "Employment-focused entry navigation", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation, employment_focused: true) }

  it "renders the employment-focused entry content and navigates to add-your-work screen" do
    visit activities_flow_start_path(token: invitation.auth_token)

    verify_page(page, title: I18n.t("activities.entries.show.employment_focused.header"))
    expect(page).to have_no_content(I18n.t("activities.entries.show.title", benefit: "Medicaid"))

    click_link I18n.t("activities.entries.show.employment_focused.get_started")

    verify_page(page, title: I18n.t("activities.employment.add_your_work.show.header"))
  end

  it "renders the generic entry content when not employment_focused" do
    non_employment_invitation = create(:activity_flow_invitation, employment_focused: false)
    visit activities_flow_start_path(token: non_employment_invitation.auth_token)

    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    expect(page).to have_no_content(I18n.t("activities.entries.show.employment_focused.header"))
  end
end
