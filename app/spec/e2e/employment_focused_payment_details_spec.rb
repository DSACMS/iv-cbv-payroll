require "rails_helper"

RSpec.describe "Employment-focused payment details copy", :js, type: :feature do
  include E2e::TestHelpers
  include PinwheelApiHelper
  include_context "activity_hub"

  let(:account_id) { "03e29160-f7e7-4a28-b2d8-813640e030d3" }

  before do
    pinwheel_stub_request_identity_response
    pinwheel_stub_request_end_user_accounts_response
    pinwheel_stub_request_end_user_account_response
    pinwheel_stub_request_platform_response
    pinwheel_stub_request_income_metadata_response
    pinwheel_stub_request_employment_info_response
    pinwheel_stub_request_end_user_paystubs_response
  end

  context "for an employment_focused activity" do
    let(:employment_focused) { true }

    it "shows employment and monthly details for a single-month report" do
      open_payment_details(months: 1)
      expect(page).to have_selector("table", count: 2)
      verify_employment_details_copy
    end

    it "shows employment and monthly details for a three-month report" do
      open_payment_details(months: 3)
      expect(page).to have_selector("table", count: 4)
      verify_employment_details_copy
    end
  end

  context "for a standard CE activity" do
    let(:employment_focused) { false }

    it "keeps the community engagement report description" do
      open_payment_details(months: 3)

      expect(page).to have_text("This will be included in your community engagement report.")
      expect(page).to have_no_selector("h2", text: "Employment information", exact_text: true)
    end
  end

  def verify_employment_details_copy
    expect(page).to have_text("Please review your information.")
    expect(page).to have_no_text("This will be included in your community engagement report.")
    expect(page.all("h2").map(&:text).first(3)).to eq(
      [ "Employment information", "Monthly details", "Additional comments (optional)" ]
    )
    within(page.all("table").first) do
      [ "Employment start date", "Employment end date", "Employment status", "Pay frequency", "Compensation amount" ].each do |label|
        expect(page).to have_text(label)
      end
    end
    ActivityFlow.last.reporting_months.each do |month|
      within("table[aria-label='#{I18n.l(month, format: :month_year)}']") do
        [ "Month", "Gross income", "Number of paychecks", "Hours worked" ].each do |label|
          expect(page).to have_text(label)
        end
        expect(page).to have_text(I18n.l(month, format: :month_year))
      end
    end
    expect(page).to have_field("payroll_account[additional_information]")
    expect(page).to have_no_text("Community engagement hours")
  end

  def open_payment_details(months:)
    invitation = create(:activity_flow_invitation, employment_focused: employment_focused)
    visit activities_flow_start_path(token: invitation.auth_token)
    entry_title = employment_focused ? "activities.entries.show.employment_focused.header" : "activities.entries.show.title"
    verify_page(page, title: I18n.t(entry_title, benefit: "Medicaid"))
    flow = ActivityFlow.last
    flow.update!(reporting_window_months: months)
    create(:payroll_account, :pinwheel_fully_synced, flow: flow, aggregator_account_id: account_id)

    visit activities_flow_income_payment_details_path(user: { account_id: account_id })
    verify_page(page, title: I18n.t("activities.income.payment_details.show.header", employer_name: ""))
  end
end
