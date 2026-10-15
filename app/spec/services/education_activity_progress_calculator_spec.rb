require "rails_helper"

RSpec.describe EducationActivityProgressCalculator do
  let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
  let(:education_activity) { create(:education_activity, activity_flow: flow, status: "succeeded") }
  let(:calculator) { described_class.new(education_activity) }
  let(:month_start) { flow.reporting_window_range.begin }

  describe "#progress_hours_for_month" do
    context "when a manual term has not been entered" do
      let(:education_activity) do
        create(
          :education_activity,
          activity_flow: flow,
          data_source: :fully_self_attested,
          school_name: "Test U",
          status: "unknown"
        )
      end

      it "returns zero progress hours" do
        expect(calculator.progress_hours_for_month(month_start)).to eq(0)
      end
    end

    context "with a self-attested term" do
      let(:flow) { create(:activity_flow, reporting_window_months: 3, education_activities_count: 0) }
      let(:enrollment_status) { "less_than_half_time" }
      let(:credit_hours) { 3.5 }
      let(:term_start) { flow.reporting_months.first }
      let(:education_activity) do
        create(:education_activity, activity_flow: flow, data_source: :fully_self_attested, school_name: "Test U",
          self_attested_term_start: term_start, self_attested_term_end: flow.reporting_months.last,
          self_attested_enrollment_status: enrollment_status, credit_hours: credit_hours)
      end

      it "converts fractional term credits into monthly CE hours" do
        expect(calculator.progress_hours_for_month(month_start)).to eq(credit_hours * EducationActivity::CREDIT_HOUR_CE_MULTIPLIER)
      end

      context "with full-time enrollment" do
        let(:enrollment_status) { "full_time" }
        let(:credit_hours) { nil }

        it "meets the monthly enrollment requirement" do
          expect(calculator.progress_hours_for_month(month_start)).to eq(ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD)
          expect(calculator).to be_sufficient_enrollment_for_month(month_start)
        end

        it "keeps self-attested activities in the upload flow" do
          expect(calculator.routing_hours_for_month(month_start)).to eq(0)
        end
      end

      context "with half-time enrollment" do
        let(:enrollment_status) { "half_time" }
        let(:credit_hours) { nil }

        it "meets the monthly enrollment requirement" do
          expect(calculator.progress_hours_for_month(month_start)).to eq(ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD)
          expect(calculator).to be_sufficient_enrollment_for_month(month_start)
        end
      end

      context "with unknown enrollment and no credits" do
        let(:enrollment_status) { "unknown" }
        let(:credit_hours) { nil }

        it "contributes zero hours" do
          expect(calculator.progress_hours_for_month(month_start)).to eq(0)
        end
      end

      context "outside the term dates" do
        let(:term_start) { flow.reporting_months.second }

        it "contributes zero hours" do
          expect(calculator.progress_hours_for_month(month_start)).to eq(0)
        end
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

        expect(calculator.progress_hours_for_month(month_start)).to eq(78)
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

  describe "#sufficient_enrollment_for_month?" do
    it "returns true when the month has half-time or above enrollment" do
      create(
        :nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: month_start,
        term_end: month_start.end_of_month
      )

      expect(calculator).to be_sufficient_enrollment_for_month(month_start)
    end

    it "returns false when the month uses self-attested credit hours" do
      education_activity.update!(data_source: :fully_self_attested, school_name: "Test U", status: "unknown",
        self_attested_term_start: month_start - 1.month, self_attested_term_end: month_start,
        self_attested_enrollment_status: "less_than_half_time", credit_hours: 7)

      expect(calculator).not_to be_sufficient_enrollment_for_month(month_start)
    end

    it "returns true when summer carryover applies" do
      flow.update!(reporting_window_months: 2)
      flow.shift_reporting_window_start!("2025-07-01")
      july = Date.new(2025, 7, 1)
      create(
        :nsc_enrollment_term,
        education_activity: education_activity,
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 3, 1),
        term_end: Date.new(2025, 6, 15)
      )

      expect(calculator).to be_sufficient_enrollment_for_month(july)
    end

    it "returns false when the month has less-than-half-time enrollment" do
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: education_activity,
        term_begin: month_start,
        term_end: month_start.end_of_month,
        credit_hours: 20
      )

      expect(calculator).not_to be_sufficient_enrollment_for_month(month_start)
    end
  end
end
