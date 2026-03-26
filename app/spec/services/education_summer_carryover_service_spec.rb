require "rails_helper"

RSpec.describe EducationSummerCarryoverService do
  describe ".applies?" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
    let(:education_activity) { create(:education_activity, activity_flow: flow, status: "succeeded") }
    let(:month_start) { Date.new(2025, 7, 1) }

    before do
      flow.shift_reporting_window_start!("2025-07-01")
    end

    it "uses a qualifying spring term when summer enrollment is less than half time" do
      spring_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 3, 1),
        term_end: Date.new(2025, 6, 15))
      summer_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "less_than_half_time",
        term_begin: Date.new(2025, 7, 1),
        term_end: Date.new(2025, 8, 15))

      expect(described_class.applies?([ spring_term, summer_term ], month_start)).to be(true)
    end

    it "does not use a qualifying spring term from a prior year" do
      prior_spring_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2024, 3, 1),
        term_end: Date.new(2024, 6, 15))
      summer_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "less_than_half_time",
        term_begin: Date.new(2025, 7, 1),
        term_end: Date.new(2025, 8, 15))

      expect(described_class.applies?([ prior_spring_term, summer_term ], month_start)).to be(false)
    end

    it "can evaluate passed-in terms without reading from the activity" do
      spring_term = build(
        :nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 3, 1),
        term_end: Date.new(2025, 6, 15)
      )
      summer_term = build(
        :nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "less_than_half_time",
        term_begin: Date.new(2025, 7, 1),
        term_end: Date.new(2025, 8, 15)
      )

      expect(described_class.applies?([ spring_term, summer_term ], month_start)).to be(true)
    end
  end

  describe ".effective_term_for_month" do
    let(:flow) { create(:activity_flow, reporting_window_months: 2, education_activities_count: 0) }
    let(:education_activity) { create(:education_activity, activity_flow: flow, status: "succeeded") }
    let(:month_start) { Date.new(2025, 6, 1) }

    before do
      flow.shift_reporting_window_start!("2025-06-01")
    end

    it "returns the higher-priority overlapping validated term" do
      stronger_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 3, 1),
        term_end: Date.new(2025, 6, 15))
      weaker_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "less_than_half_time",
        term_begin: Date.new(2025, 6, 1),
        term_end: Date.new(2025, 7, 31))

      expect(
        described_class.effective_term_for_month([ stronger_term, weaker_term ], month_start)
      ).to eq(stronger_term)
    end

    it "returns the carryover spring term when it outranks the summer term" do
      spring_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 3, 1),
        term_end: Date.new(2025, 6, 15))
      summer_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "less_than_half_time",
        term_begin: Date.new(2025, 7, 1),
        term_end: Date.new(2025, 8, 15))

      expect(
        described_class.effective_term_for_month([ spring_term, summer_term ], Date.new(2025, 7, 1))
      ).to eq(spring_term)
    end

    it "returns the carryover spring term when no summer term exists" do
      spring_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 3, 1),
        term_end: Date.new(2025, 6, 15))

      expect(
        described_class.effective_term_for_month([ spring_term ], Date.new(2025, 7, 1))
      ).to eq(spring_term)
    end

    it "returns the displayed summer term when carryover does not apply" do
      summer_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "less_than_half_time",
        term_begin: Date.new(2025, 7, 1),
        term_end: Date.new(2025, 8, 15))

      expect(
        described_class.effective_term_for_month([ summer_term ], Date.new(2025, 7, 1))
      ).to eq(summer_term)
    end
  end
end
