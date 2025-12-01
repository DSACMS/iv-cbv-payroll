require 'rails_helper'

RSpec.describe VolunteeringActivity, type: :model do
  it 'has fields for organization_name, date, and hours' do
    activity_flow = ActivityFlow.create!
    activity = VolunteeringActivity.new(
      activity_flow: activity_flow,
      organization_name: "Daph's Fun House",
      date: Date.new(2000, 2, 20),
      hours: 2
    )

    expect(activity.organization_name).to eq("Daph's Fun House")
    expect(activity.date).to eq(Date.new(2000, 2, 20))
    expect(activity.hours).to eq(2)
  end
end
