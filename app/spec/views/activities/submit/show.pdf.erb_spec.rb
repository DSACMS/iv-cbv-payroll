require "rails_helper"

RSpec.describe "activities/submit/show.pdf.erb", type: :view do
  let(:flow) do
    create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0,
      education_activities_count: 0, employment_activities_count: 0, reporting_window_months: 3)
  end
  let(:enrollment_status) { "less_than_half_time" }
  let(:credit_hours) { 3.5 }
  let(:education_activity) do
    create(:education_activity, activity_flow: flow, data_source: :fully_self_attested, school_name: "Test University",
      self_attested_term_start: flow.reporting_months.first, self_attested_term_end: flow.reporting_months.last,
      self_attested_enrollment_status: enrollment_status, credit_hours: credit_hours)
  end
  let(:document) { Capybara.string(rendered) }
  let(:term_date_range) do
    I18n.t("activities.submit.pdf.term_date_range",
      start_date: I18n.l(education_activity.self_attested_term_start, format: :month_year),
      end_date: I18n.l(education_activity.self_attested_term_end, format: :month_year))
  end
  let(:term_table) { document.find("table", text: term_date_range) }

  before do
    education_activity
    assign(:report, ActivityPdfReport.new(flow: flow, caseworker: false))
    render
  end

  it "renders the manual term and fractional credits" do
    expect(document).to have_text(term_date_range)
    expect(document).to have_text(I18n.t("activities.education.add_your_term.edit.enrollment_status_options.less_than_half_time"))
    expect(document).to have_text(ApplicationHelper.format_decimal_amount(credit_hours))
    expect(document).to have_text(ApplicationHelper.format_decimal_amount(education_activity.community_engagement_hours(credit_hours)))
  end

  it "gives the report information table an accessible name" do
    expect(document).to have_selector("h2#client-and-report-information")
    expect(document).to have_selector('table[aria-labelledby="client-and-report-information"]')
  end

  it "renders all four education summary columns" do
    expect(term_table).to have_selector("thead th", text: I18n.t("activities.education.review.term"))
    expect(term_table).to have_selector("thead th", text: I18n.t("components.enrollment_term_table_component.enrollment_status"))
    expect(term_table).to have_selector("thead th", text: I18n.t("activities.summary.education.credit_hours"))
    expect(term_table).to have_selector("thead th", text: I18n.t("activities.summary.education.community_engagement_hours"))
  end

  context "with full-time enrollment" do
    let(:enrollment_status) { "full_time" }
    let(:credit_hours) { nil }

    it "renders the enrollment status and term" do
      expect(document).to have_text(I18n.t("activities.education.add_your_term.edit.enrollment_status_options.full_time"))
      expect(document).to have_text(term_date_range)
    end

    it "renders credits and community engagement hours as not applicable" do
      expect(term_table).to have_selector("thead th", text: I18n.t("activities.summary.education.credit_hours"))
      expect(term_table).to have_selector("tbody td", text: I18n.t("shared.not_applicable"), count: 2)
    end
  end

  context "with half-time enrollment" do
    let(:enrollment_status) { "half_time" }
    let(:credit_hours) { nil }

    it "renders credits and community engagement hours as not applicable" do
      expect(term_table).to have_text(education_activity.self_attested_enrollment_status_display)
      expect(term_table).to have_selector("tbody td", text: I18n.t("shared.not_applicable"), count: 2)
    end
  end
end
