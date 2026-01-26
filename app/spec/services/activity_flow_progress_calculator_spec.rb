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
end
