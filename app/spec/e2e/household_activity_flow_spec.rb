require "rails_helper"

RSpec.describe "e2e Household activity flow", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:primary_member_name) { "Dominic Santos" }
  let(:secondary_member_name) { "Lamine Santos" }

  it "returns to the household list after each member submits" do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
    # Launch a fresh test household
    visit "/launcher/advanced"

    find("label[for='launch_mode_household']").click
    click_button "Copy link"
    expect(page).to have_button("Link copied", wait: 10)
    household_path = household_start_path(token: Household.order(:created_at).last.auth_token)

    visit household_path
    verify_page(page, title: I18n.t("households.show.title"))

    # Complete the primary member and return to the household list
    submit_household_member_report(primary_member_name, I18n.t("activities.hub.in_progress_state_title"))

    expect(page).to have_current_path(household_path)
    verify_page(page, title: I18n.t("households.show.title"))
    expect(completed_member_activity_flow_count(primary_member_name)).to eq(1)
    within_household_member(primary_member_name) do
      expect(page).to have_button(I18n.t("households.show.completed"), disabled: true)
      expect(page).to have_no_button(I18n.t("households.show.launch"))
    end
    within_household_member(secondary_member_name) do
      expect(page).to have_button(I18n.t("households.show.launch"))
      expect(page).to have_no_button(I18n.t("households.show.completed"))
    end

    # Complete the second member from the same household link
    submit_household_member_report(secondary_member_name, I18n.t("activities.hub.empty_state_title"))

    expect(page).to have_current_path(household_path)
    verify_page(page, title: I18n.t("households.show.title"))
    expect(completed_member_activity_flow_count(primary_member_name)).to eq(1)
    expect(completed_member_activity_flow_count(secondary_member_name)).to eq(1)
  end

  def submit_household_member_report(display_name, initial_hub_title)
    within_household_member(display_name) do
      click_button I18n.t("households.show.launch")
    end

    verify_page(page, title: initial_hub_title)

    flow = member_activity_flows(display_name).order(created_at: :desc).first
    add_community_service_activity(flow, "#{display_name} Food Pantry")

    visit activities_flow_root_path
    verify_page(page, title: I18n.t("activities.hub.completed_state_title"))

    click_button I18n.t("activities.hub.review_and_submit")
    verify_page(page, title: I18n.t("activities.summary.title", benefit: I18n.t("shared.benefit.sandbox")))

    find("label[for='activity_flow_consent_to_submit']").click
    click_button I18n.t("activities.summary.submit", agency_name: I18n.t("shared.agency_full_name.sandbox"))
  end

  def add_community_service_activity(flow, organization_name)
    activity = create(
      :volunteering_activity,
      activity_flow: flow,
      organization_name: organization_name,
      draft: false
    )

    flow.reporting_months.each do |month|
      create(
        :volunteering_activity_month,
        volunteering_activity: activity,
        month: month.beginning_of_month,
        hours: 80
      )
    end
  end

  def within_household_member(display_name, &block)
    within(find(".household-member-card", text: display_name), &block)
  end

  def member_activity_flows(display_name)
    HouseholdMember.find_by!(display_name: display_name).activity_flow_invitation.activity_flows
  end

  def completed_member_activity_flow_count(display_name)
    member_activity_flows(display_name).completed.count
  end
end
