require 'rails_helper'

RSpec.describe JobTrainingActivity, type: :model do
  it 'stores program name, organization address, hours, and date' do
    activity = create(:job_training_activity,
      program_name: 'Resume Workshop',
      organization_address: '123 Main St, Baton Rouge, LA',
      hours: 12
    )

    expect(activity.program_name).to eq('Resume Workshop')
    expect(activity.organization_address).to eq('123 Main St, Baton Rouge, LA')
    expect(activity.hours).to eq(12)
    expect(activity.date).to be_present
  end

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
end
