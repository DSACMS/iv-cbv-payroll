require "rails_helper"

RSpec.describe "e2e Household activity flow", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:primary_member_name) { "Dominic Santos" }
  let(:secondary_member_name) { "Lamine Santos" }

  it "switches between mutually exclusive individual and household setup modes" do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
    visit "/launcher/advanced"

    click_button "3 months"
    expect(page).to have_field("reporting_window_months", with: "3", visible: :all)

    find("#nsc-test-scenarios-button").click
    find("label[for='test_scenario_lynette']").click
    expect(page).to have_checked_field("test_scenario_lynette", visible: :all)
    fill_in "reporting_window_start", with: "06/01/2025"

    find("label[for='launch_mode_household']").click

    expect(page).to have_no_selector("input[name='test_scenario']:checked", visible: :all)
    expect(page).to have_checked_field("household_archetype_needs_documentation_one_activity", visible: :all)
    expect(page).to have_checked_field("household_archetype_needs_documentation_multiple_activities", visible: :all)
    expect(page).to have_selector("label[for='flow_type_activity']", visible: :visible)
    expect(page).to have_field("flow_type_cbv", disabled: true, visible: :all)
    expect(page).to have_text("Reporting window start")
    expect(page).to have_field("reporting_window_start", with: "06/01/2025", visible: :all)
    expect(page).to have_field("launcher_timeout", visible: :all)
    expect(page).to have_checked_field("launch_type_tokenized", visible: :all)
    expect(page).to have_field("launch_type_generic", disabled: true, visible: :all)
    expect(page).to have_button("Copy link", disabled: false)
    expect(page).to have_button("Open in new tab", disabled: false)

    find("label[for='household_archetype_needs_documentation_one_activity']").click
    find("label[for='household_archetype_needs_documentation_multiple_activities']").click
    expect(page).to have_no_selector("input[name='household_archetypes[]']:checked", visible: :all)
    expect(page).to have_button("Copy link", disabled: true)
    expect(page).to have_button("Open in new tab", disabled: true)
    expect(page).to have_text(I18n.t("launcher.advanced.household.selection_hint"))

    find("label[for='household_archetype_needs_documentation_one_activity']").click
    expect(page).to have_button("Copy link", disabled: false)

    find("label[for='launch_mode_individual']").click

    expect(page).to have_no_selector("input[name='household_archetypes[]']:checked", visible: :all)
    expect(page).to have_selector("label[for='flow_type_activity']", visible: :visible)
    expect(page).to have_field("flow_type_cbv", disabled: false, visible: :all)
    expect(page).to have_checked_field("launch_type_tokenized", visible: :all)
    expect(page).to have_field("launch_type_generic", disabled: false, visible: :all)
    expect(page).to have_button("Copy link")
    expect(page).to have_button("Open in new tab")

    expect(page).to have_field("volunteering_enabled", disabled: false, visible: :all)

    select "la_ldh", from: "client_agency_id"
    expect(page).to have_field("volunteering_enabled", disabled: true, visible: :all)
    expect(page).to have_field("launch_mode_household", disabled: true, visible: :all)
    expect(page).to have_text(I18n.t("launcher.advanced.household.unavailable"))
  end

  it "forces individual mode when switching to an agency without CE activities" do
    visit "/launcher/advanced"

    find("label[for='launch_mode_household']").click
    expect(page).to have_button("Copy link")

    select "la_ldh", from: "client_agency_id"

    expect(page).to have_checked_field("launch_mode_individual", visible: :all)
    expect(page).to have_field("launch_mode_household", disabled: true, visible: :all)
    expect(page).to have_no_selector("input[name='household_archetypes[]']:checked", visible: :all)
    expect(page).to have_checked_field("launch_type_tokenized", visible: :all)
  end

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
    submit_household_member_report(primary_member_name)

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
    submit_household_member_report(secondary_member_name)

    expect(page).to have_current_path(household_path)
    verify_page(page, title: I18n.t("households.show.title"))
    expect(completed_member_activity_flow_count(primary_member_name)).to eq(1)
    expect(completed_member_activity_flow_count(secondary_member_name)).to eq(1)
  end

  def submit_household_member_report(display_name)
    within_household_member(display_name) do
      click_button I18n.t("households.show.launch")
    end

    verify_page(page, title: I18n.t("activities.hub.empty_state_title"))

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
