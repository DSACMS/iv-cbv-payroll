require "rails_helper"

RSpec.describe EducationActivity do
  describe "#progress_hours_for_month" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
    let(:education_activity) { create(:education_activity, activity_flow: flow, status: "succeeded") }
    let(:month_start) { flow.reporting_window_range.begin }

    context "when sync has not succeeded" do
      let(:education_activity) { create(:education_activity, activity_flow: flow, status: "unknown") }

      it "returns 0 hours" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")
        expect(education_activity.progress_hours_for_month(month_start)).to eq(0)
      end
    end

    context "when sync succeeded but no enrollment terms exist" do
      it "returns 0 hours" do
        expect(education_activity.progress_hours_for_month(month_start)).to eq(0)
      end
    end

    context "when enrollment terms exist for the month" do
      it "returns 80 hours when all terms are full_time" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")
        expect(education_activity.progress_hours_for_month(month_start)).to eq(80)
      end

      it "returns 80 hours when all terms are three_quarter_time" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "three_quarter_time")
        expect(education_activity.progress_hours_for_month(month_start)).to eq(80)
      end

      it "returns 80 hours when all terms are half_time" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "half_time")
        expect(education_activity.progress_hours_for_month(month_start)).to eq(80)
      end

      it "returns 0 hours when any term is less_than_half_time" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "less_than_half_time")
        expect(education_activity.progress_hours_for_month(month_start)).to eq(0)
      end

      it "returns 0 hours when term status is enrolled (unspecified)" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "enrolled")
        expect(education_activity.progress_hours_for_month(month_start)).to eq(0)
      end

      it "returns 80 hours when multiple terms all meet half_time_or_above" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "half_time")
        expect(education_activity.progress_hours_for_month(month_start)).to eq(80)
      end
    end

    context "when enrollment term does not overlap with the month" do
      it "returns 0 hours" do
        # Create a term that ends before the reporting window
        create(:nsc_enrollment_term,
               education_activity: education_activity,
               enrollment_status: "full_time",
               term_begin: month_start - 3.months,
               term_end: month_start - 1.month)
        expect(education_activity.progress_hours_for_month(month_start)).to eq(0)
      end
    end
  end
end
