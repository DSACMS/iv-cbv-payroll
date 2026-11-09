require "rails_helper"

RSpec.describe EnrollmentDetailsComponent, type: :component do
  subject(:rendered) { render_inline(described_class.new(enrollment_terms: terms)) }

  let(:education) { create(:education_activity) }
  let(:older) do
    create(:nsc_enrollment_term, :full_time, education_activity: education,
      school_certified_on: Date.new(2026, 9, 1))
  end
  let(:latest) do
    create(:nsc_enrollment_term, education_activity: education,
      enrollment_status: :withdrawn, school_certified_on: Date.new(2026, 9, 15))
  end
  let(:terms) { [ latest, older ] }

  it "shows the latest certified status in the main enrollment table" do
    expect(rendered.css("table").first).to have_text("Withdrawn (As of September 15, 2026)", normalize_ws: true)
    expect(rendered.css("table").first).to have_no_text("Full-time")
  end

  it "shows the actual term dates rather than the certification date as the term" do
    expect(rendered.css("table").first).to have_text(I18n.l(latest.term_begin, format: :long))
    expect(rendered.css("table").first).to have_text(I18n.l(latest.term_end, format: :long))
  end

  it "puts previous statuses in a collapsed history accordion" do
    expect(rendered).to have_selector("button[aria-expanded='false']", text: "View enrollment history")
    expect(rendered.css(".usa-accordion__content")).to have_text("Full-time (As of September 1, 2026)", normalize_ws: true)
    expect(rendered.css(".usa-accordion__content")).to have_no_text("Withdrawn")
  end

  it "uses the shared details-table style for the current enrollment and its history" do
    expect(rendered).to have_selector("table.details-table", count: 2)
  end

  it "italicizes the parenthesized certification dates in the current status and history" do
    expect(rendered.css("table").first).to have_selector("em", text: "(As of September 15, 2026)")
    expect(rendered.css(".usa-accordion__content")).to have_selector("em", text: "(As of September 1, 2026)")
  end

  context "when creation order differs from certification order" do
    let(:terms) { [ older, latest ] }

    before do
      latest.update_columns(created_at: 2.days.ago)
      older.update_columns(created_at: 1.day.ago)
    end

    it "still selects the latest certification" do
      expect(rendered.css("table").first).to have_text("Withdrawn")
    end
  end

  context "with several historical statuses" do
    let(:middle) do
      create(:nsc_enrollment_term, education_activity: education,
        school_certified_on: Date.new(2026, 9, 8))
    end
    let(:terms) { [ older, latest, middle ] }

    it "orders history by certification date, newest first" do
      rows = rendered.css(".usa-accordion__content tbody tr")
      expect(rows.first).to have_text("Half-time (As of September 8, 2026)", normalize_ws: true)
      expect(rows.last).to have_text("Full-time (As of September 1, 2026)", normalize_ws: true)
    end
  end

  context "with a different school" do
    let(:other_school) do
      create(:nsc_enrollment_term, education_activity: education, school_name: "Other College")
    end
    let(:terms) { [ latest, older, other_school ] }

    it "keeps the other school's enrollment separate" do
      expect(rendered).to have_selector("h2", text: "Enrollment #1 information")
      expect(rendered).to have_selector("h2", text: "Enrollment #2 information")
      expect(rendered).to have_text("Other College", count: 1)
      expect(rendered).to have_button("View enrollment history", count: 1)
    end
  end

  context "with a different term at the same school" do
    let(:other_term) do
      create(:nsc_enrollment_term, education_activity: education,
        term_begin: latest.term_begin - 1.month, term_end: latest.term_end - 1.month)
    end
    let(:terms) { [ latest, older, other_term ] }

    it "keeps the other term separate" do
      expect(rendered).to have_selector("h2", text: "Enrollment #2 information")
      expect(rendered).to have_button("View enrollment history", count: 1)
    end
  end

  context "without previous records" do
    let(:terms) { [ latest ] }

    it "omits the history accordion" do
      expect(rendered).to have_no_button("View enrollment history")
    end
  end

  context "when the latest status is enrolled" do
    before { latest.update!(enrollment_status: :enrolled) }

    it "shows the enrollment details without a status row" do
      enrollment_table = rendered.css("table").first

      expect(enrollment_table).to have_text(latest.school_name.titlecase)
      expect(enrollment_table).to have_text(I18n.l(latest.term_begin, format: :long))
      expect(enrollment_table).to have_text(I18n.l(latest.term_end, format: :long))
      expect(enrollment_table).to have_no_selector("tr", text: I18n.t("components.enrollment_term_table_component.enrollment_status"))
    end

    it "keeps other statuses in enrollment history" do
      expect(rendered).to have_button(I18n.t("activities.education.edit.enrollment_history"))
      expect(rendered).to have_selector(".usa-accordion__content", text: older.enrollment_status_display)
    end

    context "when the previous status is also enrolled" do
      before { older.update!(enrollment_status: :enrolled) }

      it "hides status rows and the empty history accordion" do
        expect(rendered).to have_no_selector("tr", text: I18n.t("components.enrollment_term_table_component.enrollment_status"))
        expect(rendered).to have_no_button(I18n.t("activities.education.edit.enrollment_history"))
      end
    end
  end

  context "when the only historical status is enrolled" do
    before { older.update!(enrollment_status: :enrolled) }

    it "shows the latest status without a history accordion" do
      expect(rendered).to have_text(latest.enrollment_status_display)
      expect(rendered).to have_no_button(I18n.t("activities.education.edit.enrollment_history"))
    end
  end

  context "with enrolled and other historical statuses" do
    let(:enrolled_history) do
      create(:nsc_enrollment_term, :enrolled, education_activity: education,
        school_certified_on: Date.new(2026, 9, 5))
    end
    let(:terms) { [ latest, enrolled_history, older ] }

    it "shows other historical statuses and hides enrolled" do
      expect(rendered).to have_selector(".usa-accordion__content", text: older.enrollment_status_display)
      expect(rendered).to have_no_text(enrolled_history.enrollment_status_display)
    end
  end

  context "with enrolled and other terms" do
    let(:enrolled_term) do
      create(:nsc_enrollment_term, :enrolled, education_activity: education, school_name: "Other College")
    end
    let(:terms) { [ latest, enrolled_term ] }

    it "keeps both enrollments and shows only the other status row" do
      expect(rendered).to have_text(enrolled_term.school_name)
      expect(rendered).to have_selector("tr", text: I18n.t("components.enrollment_term_table_component.enrollment_status"), count: 1)
      expect(rendered).to have_text(latest.enrollment_status_display)
      expect(rendered).to have_no_text(enrolled_term.enrollment_status_display)
    end
  end

  context "when the same status was certified on different dates" do
    before { older.update!(enrollment_status: :withdrawn) }

    it "keeps the earlier certification in history" do
      expect(rendered.css(".usa-accordion__content")).to have_text("Withdrawn (As of September 1, 2026)", normalize_ws: true)
    end
  end

  context "with an undated legacy record" do
    before { older.update_columns(school_certified_on: nil) }

    it "prefers the dated record without inventing a historical certification date" do
      expect(rendered.css("table").first).to have_text("Withdrawn")
      expect(rendered.css(".usa-accordion__content")).to have_text("Full-time")
      expect(rendered.css(".usa-accordion__content")).to have_no_text("As of")
    end
  end
end
