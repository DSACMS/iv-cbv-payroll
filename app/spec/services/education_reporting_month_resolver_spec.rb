require "rails_helper"

RSpec.describe EducationReportingMonthResolver do
  let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
  let(:education_activity) { create(:education_activity, activity_flow: flow, status: "succeeded") }

  describe "#result_for" do
    it "returns the higher-priority overlapping term when carryover does not apply" do
      month_start = Date.new(2025, 6, 1)
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

      result = described_class.new(
        terms: [ stronger_term, weaker_term ],
        reporting_months: [ month_start ]
      ).result_for(month_start)

      expect(result.effective_term).to eq(stronger_term)
      expect(result.terms).to contain_exactly(stronger_term, weaker_term)
      expect(result).to be_sufficient_enrollment
    end

    it "returns the qualifying spring term for summer when no summer term exists" do
      july = Date.new(2025, 7, 1)
      spring_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 3, 1),
        term_end: Date.new(2025, 6, 15))

      result = described_class.new(
        terms: [ spring_term ],
        reporting_months: [ july ]
      ).result_for(july)

      expect(result.effective_term).to eq(spring_term)
      expect(result.terms).to be_empty
      expect(result).to be_sufficient_enrollment
    end

    it "uses the summer term when summer enrollment is half-time or above" do
      july = Date.new(2025, 7, 1)
      spring_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 3, 1),
        term_end: Date.new(2025, 6, 15))
      summer_term = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 7, 1),
        term_end: Date.new(2025, 8, 15))

      result = described_class.new(
        terms: [ spring_term, summer_term ],
        reporting_months: [ july ]
      ).result_for(july)

      expect(result.effective_term).to eq(summer_term)
      expect(result).to be_sufficient_enrollment
    end
  end

  describe "#terms_for_reporting_months" do
    it "includes carryover spring terms for each summer year in the reporting months" do
      july_2025 = Date.new(2025, 7, 1)
      july_2026 = Date.new(2026, 7, 1)
      spring_2025 = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 3, 1),
        term_end: Date.new(2025, 6, 15))
      spring_2026 = create(:nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2026, 3, 1),
        term_end: Date.new(2026, 6, 15))

      resolver = described_class.new(
        terms: [ spring_2025, spring_2026 ],
        reporting_months: [ july_2025, july_2026 ]
      )

      expect(resolver.terms_for_reporting_months).to contain_exactly(spring_2025, spring_2026)
      expect(resolver.result_for(july_2025).effective_term).to eq(spring_2025)
      expect(resolver.result_for(july_2026).effective_term).to eq(spring_2026)
    end
  end
end
