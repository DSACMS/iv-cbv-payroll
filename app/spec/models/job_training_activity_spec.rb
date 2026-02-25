require 'rails_helper'

RSpec.describe JobTrainingActivity, type: :model do
  describe "date validation" do
    let(:activity_flow) { create(:activity_flow, reporting_window_months: 1, job_training_activities_count: 0) }

    it "is valid when date is within reporting window" do
      activity = create(:job_training_activity, activity_flow: activity_flow)

      expect(activity).to be_persisted
    end

    it "is invalid when date is outside reporting window" do
      activity = build(:job_training_activity, activity_flow: activity_flow, date: activity_flow.reporting_window_range.end + 1.day)

      expect(activity).not_to be_valid
      expect(activity.errors[:date]).to be_present
    end
  end

  describe "name validations" do
    let(:activity_flow) { create(:activity_flow, reporting_window_months: 1, job_training_activities_count: 0) }

    it "is invalid without an organization name" do
      activity = build(:job_training_activity, activity_flow: activity_flow, organization_name: nil)

      expect(activity).not_to be_valid
      expect(activity.errors[:organization_name]).to include("Enter the organization or provider name.")
    end

    it "is invalid without a program name" do
      activity = build(:job_training_activity, activity_flow: activity_flow, program_name: nil)

      expect(activity).not_to be_valid
      expect(activity.errors[:program_name]).to include("Enter the program name.")
    end
  end
end
