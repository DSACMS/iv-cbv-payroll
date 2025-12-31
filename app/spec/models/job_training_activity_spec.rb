require 'rails_helper'

RSpec.describe JobTrainingActivity, type: :model do
  it 'stores program name, organization address, hours, and date' do
    flow = create(:activity_flow)

    activity = JobTrainingActivity.new(
      activity_flow: flow,
      program_name: 'Resume Workshop',
      organization_address: '123 Main St, Baton Rouge, LA',
      hours: 12,
      date: Date.current
    )

    expect(activity).to be_valid
    expect(activity.program_name).to eq('Resume Workshop')
    expect(activity.organization_address).to eq('123 Main St, Baton Rouge, LA')
    expect(activity.hours).to eq(12)
    expect(activity.date).to eq(Date.current)
  end

  describe "date validation" do
    let(:activity_flow) { create(:activity_flow, reporting_month: Date.new(2025, 2, 1), job_training_activities_count: 0) }

    it "is valid when date is within reporting month" do
      activity = JobTrainingActivity.new(activity_flow: activity_flow, date: Date.new(2025, 2, 15))

      expect(activity).to be_valid
    end

    it "is invalid when date is outside reporting month" do
      activity = JobTrainingActivity.new(activity_flow: activity_flow, date: Date.new(2025, 3, 1))

      expect(activity).not_to be_valid
      expect(activity.errors[:date]).to be_present
    end
  end
end
