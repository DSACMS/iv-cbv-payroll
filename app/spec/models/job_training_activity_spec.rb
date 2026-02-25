require 'rails_helper'

RSpec.describe JobTrainingActivity, type: :model do
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

  describe "#document_upload_months_to_verify" do
    it "returns months from monthly hour records when present" do
      activity_flow = create(:activity_flow, reporting_window_months: 2, job_training_activities_count: 0)
      activity = create(:job_training_activity, activity_flow: activity_flow)
      first_month = activity.activity_flow.reporting_months.first.beginning_of_month
      second_month = activity.activity_flow.reporting_months.second.beginning_of_month
      create(:job_training_activity_month, job_training_activity: activity, month: first_month, hours: 5)
      create(:job_training_activity_month, job_training_activity: activity, month: second_month, hours: 10)

      expect(activity.document_upload_months_to_verify).to eq([ first_month, second_month ])
    end

    it "returns an empty list when no monthly records exist" do
      activity = create(:job_training_activity)

      expect(activity.document_upload_months_to_verify).to eq([])
    end
  end
end
