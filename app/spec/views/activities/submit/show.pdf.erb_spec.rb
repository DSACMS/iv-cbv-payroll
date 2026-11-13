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
  let(:enrollment_terms) { [] }
  let(:term_date_range) do
    I18n.t("activities.submit.pdf.term_date_range",
      start_date: I18n.l(education_activity.self_attested_term_start, format: :month_year),
      end_date: I18n.l(education_activity.self_attested_term_end, format: :month_year))
  end
  let(:term_table) { document.find("table", text: term_date_range) }

  before do
    education_activity
    enrollment_terms
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

  context "with partially self-attested NSC enrollment" do
    let(:education_activity) do
      create(:education_activity, activity_flow: flow, data_source: :partially_self_attested, status: :succeeded)
    end
    let(:nsc_status) { "enrolled" }
    let(:supplemental_status) { "less_than_half_time" }
    let(:supplemental_status_label) do
      I18n.t("activities.submit.pdf.supplemental_enrollment_status", status: "").strip
    end
    let(:school_certified_on) { flow.reporting_months.last.end_of_month }
    let(:enrollment_terms) do
      [ create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: nsc_status,
          supplemental_enrollment_status: supplemental_status, credit_hours: credit_hours,
          school_certified_on: school_certified_on) ]
    end
    let(:term_date_range) do
      I18n.t("activities.submit.pdf.term_date_range",
        start_date: I18n.l(enrollment_terms.first.term_begin, format: :month_year),
        end_date: I18n.l(enrollment_terms.first.term_end, format: :month_year))
    end
    let(:term_row) { term_table.find("tbody tr", text: term_date_range) }

    it "renders the four education summary columns" do
      expect(term_table).to have_selector("thead th", count: 4)
      expect(term_table).to have_selector("thead th", text: I18n.t("components.enrollment_term_table_component.enrollment_status"))
    end

    it "renders both enrollment statuses in the enrollment status cell" do
      status_cell = term_row.find("td", text: I18n.t("activities.submit.pdf.enrolled"))
      expect(status_cell).to have_text(I18n.t("components.enrollment_term_table_component.status_as_of_date",
        status: I18n.t("activities.submit.pdf.enrolled"), date: I18n.l(school_certified_on, format: :long)))
      expect(status_cell).to have_text(I18n.t("activities.submit.pdf.supplemental_enrollment_status",
        status: enrollment_terms.first.supplemental_enrollment_status_display))
    end

    it "preserves fractional credits and calculated community engagement hours" do
      expect(term_row).to have_selector("td", exact_text: "3.5")
      expect(term_row).to have_selector("td", exact_text: "45.5")
    end

    context "with supplied full-time enrollment" do
      let(:supplemental_status) { "full_time" }
      let(:credit_hours) { nil }

      it "renders the supplied status with inapplicable credit and community engagement hours" do
        expect(term_row).to have_text(I18n.t("activities.education.add_your_term.edit.enrollment_status_options.full_time"))
        expect(term_row).to have_selector("td", exact_text: I18n.t("shared.not_applicable"), count: 2)
      end
    end

    context "with supplied half-time enrollment" do
      let(:supplemental_status) { "half_time" }
      let(:credit_hours) { nil }

      it "renders the supplied status with inapplicable credit and community engagement hours" do
        expect(term_row).to have_text(I18n.t("activities.education.add_your_term.edit.enrollment_status_options.half_time"))
        expect(term_row).to have_selector("td", exact_text: I18n.t("shared.not_applicable"), count: 2)
      end
    end

    context "with an uncertain supplied enrollment status" do
      let(:supplemental_status) { "unknown" }

      it "renders the supplied status and fractional hours" do
        expect(term_row).to have_text(I18n.t("activities.education.add_your_term.edit.enrollment_status_options.unknown"))
        expect(term_row).to have_selector("td", exact_text: "3.5")
        expect(term_row).to have_selector("td", exact_text: "45.5")
      end
    end

    context "with no reported hours" do
      let(:supplemental_status) { nil }
      let(:credit_hours) { 0 }

      it "omits supplemental details when no status was supplied and renders zero hours" do
        expect(term_row).to have_text(I18n.t("activities.submit.pdf.enrolled"))
        expect(term_row).to have_no_text(supplemental_status_label)
        expect(term_row).to have_no_text(I18n.t("shared.not_applicable"))
        expect(term_row).to have_selector("td", exact_text: "0", count: 2)
      end
    end

    context "with an NSC less-than-half-time status" do
      let(:nsc_status) { "less_than_half_time" }
      let(:supplemental_status) { nil }

      it "uses the reviewed enrollment status and preserves fractional hours" do
        expect(term_row).to have_text(enrollment_terms.first.enrollment_status_display)
        expect(term_row).to have_no_text(supplemental_status_label)
        expect(term_row).to have_selector("td", exact_text: "3.5")
        expect(term_row).to have_selector("td", exact_text: "45.5")
      end
    end

    context "with mixed enrollment statuses for the same term" do
      let(:enrollment_terms) do
        super() + [ create(:nsc_enrollment_term, education_activity: education_activity,
          enrollment_status: :half_time, credit_hours: nil) ]
      end

      it "keeps each NSC status and its supplemental details in the same row" do
        expect(term_table).to have_selector("tbody tr", count: 2)
        first_row, second_row = term_table.all("tbody tr")
        expect(first_row).to have_text(I18n.t("activities.submit.pdf.enrolled"))
        expect(first_row).to have_text(enrollment_terms.first.supplemental_enrollment_status_display)
        expect(first_row).to have_selector("td", exact_text: "3.5")
        expect(first_row).to have_selector("td", exact_text: "45.5")
        expect(second_row).to have_text(enrollment_terms.last.enrollment_status_display)
        expect(second_row).to have_selector("td", exact_text: I18n.t("shared.not_applicable"), count: 2)
        expect(second_row).to have_no_text(supplemental_status_label)
      end
    end

    context "with only NSC half-time enrollment" do
      let(:nsc_status) { "half_time" }
      let(:supplemental_status) { nil }
      let(:credit_hours) { nil }

      it "renders only the NSC status and term columns" do
        expect(term_table).to have_selector("thead th", count: 2)
        expect(term_row).to have_text(enrollment_terms.first.enrollment_status_display)
        expect(term_table).to have_no_text(I18n.t("activities.summary.education.credit_hours"))
      end
    end
  end
end
