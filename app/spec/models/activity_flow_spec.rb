require 'rails_helper'

RSpec.describe ActivityFlow, type: :model do
  it "cleans up related volunteering activities when destroyed" do
    flow = create(:activity_flow)
    flow.volunteering_activities.create!(
      organization_name: "Daph's Fun House",
      hours: 2,
      date: Date.today
    )

    expect { flow.destroy }.to change { VolunteeringActivity.count }.by(-1)
  end
end
