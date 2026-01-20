require "rails_helper"

RSpec.describe ActivityFlowProgressCalculator do
  describe ".progress" do
    let(:flow) { create(:activity_flow) }

    subject(:progress) { described_class.progress(flow) }

    it "sums volunteering and job training hours" do
      flow.volunteering_activities.create!(organization_name: "Food Pantry", hours: 3, date: Date.current)
      flow.volunteering_activities.create!(organization_name: "Library", hours: 2, date: Date.current)
      flow.job_training_activities.create!(program_name: "Career Prep", organization_address: "123 Main St", hours: 5)

      expect(progress.total_hours).to eq(10)
    end

    it "returns zero when no activities exist" do
      expect(progress.total_hours).to eq(0)
    end

    it "does not meet requirements below the threshold" do
      flow.volunteering_activities.create!(organization_name: "Food Pantry", hours: 40, date: Date.current)

      expect(progress.meets_requirements).to be(false)
    end

    it "meets requirements when total hours meet the threshold" do
      flow.volunteering_activities.create!(organization_name: "Food Pantry", hours: 40, date: Date.current)
      flow.job_training_activities.create!(program_name: "Career Prep", organization_address: "123 Main St", hours: 40)

      expect(progress.meets_requirements).to be(true)
    end
  end
end
