require "rails_helper"

RSpec.describe ActivityFlowProgressCalculator do
  describe ".progress" do
    subject(:progress) { described_class.progress(flow) }

    let(:flow) { create(:activity_flow, reporting_window_months: 1) }

    it "sums volunteering and job training hours" do
      create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry", hours: 3)
      create(:volunteering_activity, activity_flow: flow, organization_name: "Library", hours: 2)
      create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 5)

      expect(progress.total_hours).to eq(10)
    end

    it "returns zero when no activities exist" do
      expect(progress.total_hours).to eq(0)
    end

    it "does not meet requirements when month is below 80 hours" do
      create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry", hours: 79)

      expect(progress.meets_requirements).to be(false)
    end

    it "meets requirements when month has at least 80 hours" do
      create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry", hours: 40)
      create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 40)

      expect(progress.meets_requirements).to be(true)
    end

    context "with multi-month reporting window" do
      let(:flow) { create(:activity_flow, reporting_window_months: 3) }
      let(:first_month) { flow.reporting_window_range.begin }
      let(:second_month) { first_month + 1.month }
      let(:third_month) { first_month + 2.months }

      it "does not meet requirements when any month has less than 80 hours" do
        create(:volunteering_activity, activity_flow: flow, hours: 240, date: first_month)

        expect(progress.meets_requirements).to be(false)
      end

      it "meets requirements when each month has at least 80 hours" do
        create(:volunteering_activity, activity_flow: flow, hours: 80, date: first_month)
        create(:volunteering_activity, activity_flow: flow, hours: 80, date: second_month)
        create(:volunteering_activity, activity_flow: flow, hours: 80, date: third_month)

        expect(progress.meets_requirements).to be(true)
      end
    end
  end

  describe "#reporting_months" do
    subject(:calculator) { described_class.new(flow) }

    let(:flow) { create(:activity_flow, reporting_window_months: 2) }

    around do |ex|
      Timecop.freeze(Date.parse("2026-01-01"), &ex)
    end

    it "gives the start of months prior to the reporting window" do
      expect(calculator.reporting_months).to contain_exactly(
        Date.new(2025, 12, 1),
        Date.new(2025, 11, 1)
      )
    end
  end

  describe "education progress" do
    subject(:progress) { described_class.progress(flow) }

    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
    let(:education_activity) { create(:education_activity, activity_flow: flow, status: "succeeded") }

    before { education_activity }

    context "when education has half_time or above enrollment for the month" do
      before do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "half_time")
      end

      it "adds 80 hours to total" do
        expect(progress.total_hours).to eq(80)
      end

      it "meets requirements" do
        expect(progress.meets_requirements).to be(true)
      end
    end

    context "when education has less_than_half_time enrollment" do
      before do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "less_than_half_time")
      end

      it "adds 0 hours to total" do
        expect(progress.total_hours).to eq(0)
      end

      it "does not meet requirements" do
        expect(progress.meets_requirements).to be(false)
      end
    end

    context "when education sync has not succeeded" do
      let(:education_activity) { create(:education_activity, activity_flow: flow, status: "unknown") }

      before do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")
      end

      it "adds 0 hours to total" do
        expect(progress.total_hours).to eq(0)
      end
    end

    context "when combining education with volunteering" do
      before do
        create(:volunteering_activity, activity_flow: flow, hours: 20)
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "half_time")
      end

      it "sums both activity types" do
        expect(progress.total_hours).to eq(100)
      end

      it "meets requirements" do
        expect(progress.meets_requirements).to be(true)
      end
    end

    context "with multi-month reporting window" do
      let(:flow) { create(:activity_flow, reporting_window_months: 2, education_activities_count: 0) }
      let(:first_month) { flow.reporting_window_range.begin }
      let(:second_month) { first_month + 1.month }

      context "when enrollment covers both months with half_time or above" do
        before do
          create(:nsc_enrollment_term,
                 education_activity: education_activity,
                 enrollment_status: "full_time",
                 term_begin: first_month,
                 term_end: second_month.end_of_month)
        end

        it "adds 80 hours per month (160 total)" do
          expect(progress.total_hours).to eq(160)
        end

        it "meets requirements" do
          expect(progress.meets_requirements).to be(true)
        end
      end

      context "when enrollment only covers one month" do
        before do
          create(:nsc_enrollment_term,
                 education_activity: education_activity,
                 enrollment_status: "full_time",
                 term_begin: first_month,
                 term_end: first_month.end_of_month)
        end

        it "adds 80 hours for covered month only" do
          expect(progress.total_hours).to eq(80)
        end

        it "does not meet requirements (second month has 0 hours)" do
          expect(progress.meets_requirements).to be(false)
        end
      end
    end
  end
end
