require "rails_helper"

RSpec.describe EducationActivityProgressCalculator do
  let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
  let(:education_activity) { create(:education_activity, activity_flow: flow, status: "succeeded") }
  let(:calculator) { described_class.new(education_activity) }
  let(:month_start) { flow.reporting_window_range.begin }

  describe "#progress_hours_for_month" do
    context "when fully self-attested" do
      let(:education_activity) do
        create(
          :education_activity,
          activity_flow: flow,
          data_source: :fully_self_attested,
          school_name: "Test U",
          status: "unknown"
        )
      end

      it "returns credit hours multiplied by the CE conversion value for the month" do
        create(
          :education_activity_month,
          education_activity: education_activity,
          month: month_start.beginning_of_month,
          hours: 4
        )

        expect(calculator.progress_hours_for_month(month_start)).to eq(16)
      end
    end

    context "when partially self-attested" do
      let(:education_activity) do
        create(
          :education_activity,
          activity_flow: flow,
          data_source: :partially_self_attested,
          status: "succeeded"
        )
      end

      it "returns credit-hour-based CE hours for less-than-half-time terms" do
        create(
          :nsc_enrollment_term,
          :less_than_half_time,
          education_activity: education_activity,
          term_begin: month_start,
          term_end: month_start.end_of_month,
          credit_hours: 6
        )

        expect(calculator.progress_hours_for_month(month_start)).to eq(24)
      end

      it "returns the threshold when an overlapping term is half-time or above" do
        create(
          :nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "half_time",
          term_begin: month_start,
          term_end: month_start.end_of_month
        )

        expect(calculator.progress_hours_for_month(month_start)).to eq(80)
      end

      it "applies summer logic before partial-self-attested fallback in July" do
        flow.update!(reporting_window_months: 2)
        flow.shift_reporting_window_start!("2025-06-01")
        july = Date.new(2025, 7, 1)

        create(
          :nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "half_time",
          term_begin: Date.new(2025, 3, 1),
          term_end: Date.new(2025, 6, 15)
        )
        create(
          :nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "half_time",
          term_begin: july,
          term_end: Date.new(2025, 8, 15)
        )
        create(
          :nsc_enrollment_term,
          :less_than_half_time,
          education_activity: education_activity,
          term_begin: Date.new(2025, 6, 1),
          term_end: Date.new(2025, 6, 30),
          credit_hours: 4
        )

        expect(calculator.progress_hours_for_month(july)).to eq(80)
      end
    end

    context "when validated" do
      it "returns 0 when sync has not succeeded" do
        education_activity.update!(status: "unknown")
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")

        expect(calculator.progress_hours_for_month(month_start)).to eq(0)
      end

      it "returns the threshold when an overlapping term is half-time or above" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")

        expect(calculator.progress_hours_for_month(month_start)).to eq(80)
      end

      it "returns the threshold when summer carryover applies" do
        flow.shift_reporting_window_start!("2025-07-01")
        july = Date.new(2025, 7, 1)
        create(
          :nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "half_time",
          term_begin: Date.new(2025, 3, 1),
          term_end: Date.new(2025, 6, 15)
        )
        create(
          :nsc_enrollment_term,
          :less_than_half_time,
          education_activity: education_activity,
          term_begin: july,
          term_end: Date.new(2025, 8, 15)
        )

        expect(calculator.progress_hours_for_month(july)).to eq(80)
      end
    end
  end

  describe "#routing_hours_for_month" do
    context "when fully self-attested" do
      let(:education_activity) do
        create(
          :education_activity,
          activity_flow: flow,
          data_source: :fully_self_attested,
          school_name: "Test U",
          status: "unknown"
        )
      end

      it "returns 0" do
        expect(calculator.routing_hours_for_month(month_start)).to eq(0)
      end
    end

    context "when partially self-attested" do
      let(:education_activity) do
        create(
          :education_activity,
          activity_flow: flow,
          data_source: :partially_self_attested,
          status: "succeeded"
        )
      end

      it "returns 0 for less-than-half-time terms" do
        create(
          :nsc_enrollment_term,
          :less_than_half_time,
          education_activity: education_activity,
          term_begin: month_start,
          term_end: month_start.end_of_month,
          credit_hours: 6
        )

        expect(calculator.routing_hours_for_month(month_start)).to eq(0)
      end

      it "returns the threshold when summer logic applies for July" do
        flow.update!(reporting_window_months: 2)
        flow.shift_reporting_window_start!("2025-06-01")
        july = Date.new(2025, 7, 1)

        create(
          :nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "half_time",
          term_begin: Date.new(2025, 3, 1),
          term_end: Date.new(2025, 6, 15)
        )
        create(
          :nsc_enrollment_term,
          education_activity: education_activity,
          enrollment_status: "half_time",
          term_begin: july,
          term_end: Date.new(2025, 8, 15)
        )
        create(
          :nsc_enrollment_term,
          :less_than_half_time,
          education_activity: education_activity,
          term_begin: Date.new(2025, 6, 1),
          term_end: Date.new(2025, 6, 30),
          credit_hours: 4
        )

        expect(calculator.routing_hours_for_month(july)).to eq(80)
      end
    end

    context "when validated" do
      it "returns 0 when sync has not succeeded" do
        education_activity.update!(status: "unknown")
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")

        expect(calculator.routing_hours_for_month(month_start)).to eq(0)
      end

      it "returns the threshold when an overlapping term is half-time or above" do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")

        expect(calculator.routing_hours_for_month(month_start)).to eq(80)
      end
    end
  end
end
