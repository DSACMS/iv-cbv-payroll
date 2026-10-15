# frozen_string_literal: true

require "rails_helper"

RSpec.describe EducationTermDetailsComponent, type: :component do
  subject(:rendered) { render_inline(described_class.new(activity: activity)) }

  let(:activity) do
    EducationActivity.new(
      self_attested_term_start: Date.new(2026, 1, 5),
      self_attested_term_end: Date.new(2026, 5, 15),
      self_attested_enrollment_status: "less_than_half_time",
      credit_hours: 3.5
    )
  end

  it "renders term dates, enrollment status, and decimal credit hours" do
    expect(rendered).to have_selector("li", text: "Term start date: 01/05/2026", normalize_ws: true)
    expect(rendered).to have_selector("li", text: "Term end date: 05/15/2026", normalize_ws: true)
    expect(rendered).to have_selector("li", text: "Enrollment status: #{activity.self_attested_enrollment_status_display}", normalize_ws: true)
    expect(rendered).to have_selector("li", text: "Credit hours: 3.5", normalize_ws: true)
  end

  context "when term details are missing" do
    let(:activity) { EducationActivity.new }

    it "renders a fallback for each detail" do
      expect(rendered).to have_selector("li", text: I18n.t("shared.not_applicable"), count: 4)
    end
  end

  context "when credit hours are zero" do
    before { activity.credit_hours = 0 }

    it "renders zero credit hours" do
      expect(rendered).to have_selector("li", text: "Credit hours: 0", normalize_ws: true)
    end
  end
end
