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

    it "does not meet requirements below the threshold" do
      create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry", hours: 40)

      expect(progress.meets_requirements).to be(false)
    end

    it "meets requirements when total hours meet the threshold" do
      create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry", hours: 40)
      create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 40)

      expect(progress.meets_requirements).to be(true)
    end

    it "scales the threshold by reporting window months" do
      multi_month_flow = create(:activity_flow, reporting_window_months: 3)
      create(:volunteering_activity, activity_flow: multi_month_flow, organization_name: "Food Pantry", hours: 160)

      result = described_class.progress(multi_month_flow)

      expect(result.meets_requirements).to be(false)

      create(:job_training_activity, activity_flow: multi_month_flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 80)

      result = described_class.progress(multi_month_flow)

      expect(result.meets_requirements).to be(true)
    end
  end
end
