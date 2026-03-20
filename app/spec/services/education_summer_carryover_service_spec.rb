require "rails_helper"

RSpec.describe EducationSummerCarryoverService do
  describe "#applies?" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
    let(:education_activity) { create(:education_activity, activity_flow: flow, status: "succeeded") }
    let(:service) { described_class.new(education_activity) }
    let(:month_start) { Date.new(2025, 7, 1) }

    before do
      flow.shift_reporting_window_start!("2025-07-01")
    end

    it "uses a qualifying spring term when summer enrollment is less than half time" do
      create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 3, 1),
        term_end: Date.new(2025, 6, 15))
      create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "less_than_half_time",
        term_begin: Date.new(2025, 7, 1),
        term_end: Date.new(2025, 8, 15))

      expect(service.applies?(month_start)).to be(true)
    end

    it "does not use a qualifying spring term from a prior year" do
      create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2024, 3, 1),
        term_end: Date.new(2024, 6, 15))
      create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "less_than_half_time",
        term_begin: Date.new(2025, 7, 1),
        term_end: Date.new(2025, 8, 15))

      expect(service.applies?(month_start)).to be(false)
    end
  end

  describe "#effective_validated_term_for_month" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
    let(:education_activity) { create(:education_activity, activity_flow: flow, status: "succeeded") }
    let(:service) { described_class.new(education_activity) }
    let(:month_start) { Date.new(2025, 7, 1) }

    before do
      flow.shift_reporting_window_start!("2025-07-01")
    end

    it "returns the qualifying spring term when carryover applies to a summer term" do
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

      expect(service.effective_validated_term_for_month(month_start, summer_term)).to eq(spring_term)
    end

    it "returns the displayed term when carryover does not apply" do
      summer_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "less_than_half_time",
        term_begin: Date.new(2025, 7, 1),
        term_end: Date.new(2025, 8, 15))

      expect(service.effective_validated_term_for_month(month_start, summer_term)).to eq(summer_term)
    end
  end
end
