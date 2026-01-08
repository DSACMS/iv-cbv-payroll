require 'rails_helper'

RSpec.describe VolunteeringActivity, type: :model do
  it 'has fields for organization_name, date, and hours' do
    activity = VolunteeringActivity.new(
      activity_flow: create(:activity_flow),
      organization_name: "Daph's Fun House",
      date: Date.new(2000, 2, 20),
      hours: 2
    )

    expect(activity.organization_name).to eq("Daph's Fun House")
    expect(activity.date).to eq(Date.new(2000, 2, 20))
    expect(activity.hours).to eq(2)
  end

  describe "date validation" do
    let(:activity_flow) { create(:activity_flow, reporting_month: Date.new(2025, 2, 1), volunteering_activities_count: 0) }

    it "is valid when date is within reporting month" do
      activity = VolunteeringActivity.new(activity_flow: activity_flow, date: Date.new(2025, 2, 15))

      expect(activity).to be_valid
    end

    it "is invalid when date is outside reporting month" do
      activity = VolunteeringActivity.new(activity_flow: activity_flow, date: Date.new(2025, 3, 1))

      expect(activity).not_to be_valid
      expect(activity.errors[:date]).to be_present
    end
  end
end
