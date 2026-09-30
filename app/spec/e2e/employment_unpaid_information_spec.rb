require "rails_helper"

RSpec.describe "Unpaid employment information", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  it "preserves unpaid work through validation, upload, review, and editing" do # rubocop:disable RSpec/MultipleExpectations
    invitation = create(:activity_flow_invitation, client_agency_id: "sandbox")
    visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 3)
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.empty_state_title"))
    within("[data-activity-type='employment']") do
      click_button I18n.t("activities.hub.add")
    end
    verify_page(page, title: I18n.t("activities.employment.add_your_work.show.header"))
    choose I18n.t("activities.employment.add_your_work.show.options.unpaid.label"), allow_label_click: true
    click_button I18n.t("continue")
    title = I18n.t("activities.employment_info.unpaid_or_in_kind.title")
    verify_page(page, title: title)

    accordion_title = I18n.t("activities.employment_info.unpaid_or_in_kind.accordion.title")
    accordion_content = I18n.t("activities.employment_info.unpaid_or_in_kind.accordion.item_1")
    expect(page).to have_no_text(accordion_content)
    click_button accordion_title
    expect(page).to have_text(accordion_content)
    click_button accordion_title
    expect(page).to have_no_text(accordion_content)
    expect(page).to have_no_field(I18n.t("activities.employment_info.self_employed"))

    click_button I18n.t("activities.employment_info.continue")
    verify_page(page, title: title)
    expect(page).to have_text(I18n.t("activities.employment_info.unpaid_or_in_kind.employer_name_error"))
    fill_in I18n.t("activities.employment_info.unpaid_or_in_kind.employer_name"), with: "Example work"
    fill_in I18n.t("activities.employment_info.unpaid_or_in_kind.contact_name"), with: "Example contact"
    click_button I18n.t("activities.employment_info.continue")
    verify_page(page, title: I18n.t("activities.employment.month_selections.edit.title", employer_name: "Example work"))
    expect(page).to have_text(I18n.t("activities.employment.month_selections.edit.unpaid_or_in_kind_description"))

    activity = EmploymentActivity.last
    first_month, _second_month, third_month = activity.activity_flow.reporting_months
    [ first_month, third_month ].each do |month|
      find("label", text: I18n.l(month, format: :month_year), exact_text: true).click
    end
    click_button I18n.t("activities.employment.month_selections.edit.continue")

    monthly_title = I18n.t("activities.employment.hours_input.unpaid_or_in_kind.heading", organization: "Example work")
    verify_page(page, title: monthly_title)
    expect(page).to have_text(
      [ I18n.t("activities.employment.hours_input.month_indicator", current: 1, total: 2), I18n.l(first_month, format: :month) ].join(" "),
      normalize_ws: true
    )
    expect(page).to have_text(I18n.t("activities.employment.hours_input.unpaid_or_in_kind.hours_hint"))
    expect(page).to have_no_selector('input[name="employment_activity_month[gross_income]"]')
    expect(page).to have_no_selector('input[type="checkbox"]')

    click_button I18n.t("activities.employment.hours_input.continue")
    error = I18n.t("activities.employment.hours_input.unpaid_or_in_kind.error_body")
    expect(page).to have_selector(".usa-alert--error", text: error)
    expect(page).to have_selector(".usa-error-message", text: error)

    fill_in I18n.t("activities.employment.hours_input.hours_label", month: I18n.l(first_month, format: :month)), with: "12"
    click_button I18n.t("activities.employment.hours_input.continue")
    verify_page(page, title: monthly_title)
    expect(page).to have_text(
      [ I18n.t("activities.employment.hours_input.month_indicator", current: 2, total: 2), I18n.l(third_month, format: :month) ].join(" "),
      normalize_ws: true
    )
    fill_in I18n.t("activities.employment.hours_input.hours_label", month: I18n.l(third_month, format: :month)), with: "8"
    click_button I18n.t("activities.employment.hours_input.continue")
    verify_page(page, title: I18n.t("activities.document_uploads.new.title", name: "Example work"), skip_axe_rules: %w[heading-order])
    expect(page).to have_text(
      "#{I18n.l(first_month, format: :month)} (#{I18n.t("shared.hours", count: 12)})",
      normalize_ws: true
    )
    expect(page).to have_text(
      "#{I18n.l(third_month, format: :month)} (#{I18n.t("shared.hours", count: 8)})",
      normalize_ws: true
    )
    expect(page).to have_no_text(ActiveSupport::NumberHelper.number_to_currency(0))
    click_button I18n.t("activities.employment.unpaid_or_in_kind.document_upload_suggestion_title")
    suggestions = Capybara.string(I18n.t("activities.employment.unpaid_or_in_kind.document_upload_suggestion_text_html"))
    suggestions.all("li").each { |item| expect(page).to have_text(item.text) }
    click_button I18n.t("activities.document_uploads.new.continue")

    verify_page(page, title: I18n.t("activities.employment.review.title", employer_name: "Example work"))
    expect(page).to have_selector("h2", text: I18n.t("activities.employment.review.unpaid_or_in_kind.work_hours"))
    expect(page).to have_text(I18n.l(first_month, format: :month_year))
    expect(page).to have_text(I18n.l(third_month, format: :month_year))
    expect(page).to have_no_text(I18n.t("activities.employment.review.gross_income"))
    expect(page).to have_text(
      I18n.t(
        "activities.employment.review.unpaid_or_in_kind.additional_comments_description",
        agency_name: I18n.t("shared.agency_full_name.sandbox")
      )
    )

    expect(activity).to be_unpaid_or_in_kind
    visit edit_activities_flow_income_employment_path(id: activity)
    verify_page(page, title: title)
    expect(page).to have_field(I18n.t("activities.employment_info.unpaid_or_in_kind.contact_name"), with: "Example contact")
  end
end
