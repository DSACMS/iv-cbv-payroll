require 'rails_helper'

RSpec.describe ActivityFlow, type: :model do
  it "cleans up related volunteering activities when destroyed" do
    flow = create(:activity_flow)
    flow.volunteering_activities.create!(
      organization_name: "Daph's Fun House",
      hours: 2,
      date: Date.today
    )
    flow.job_training_activities.create!(
      program_name: "Resume Workshop",
      organization_address: "123 Main St, Baton Rouge, LA",
      hours: 6
    )

    expect { flow.destroy }.to change { VolunteeringActivity.count }.by(-1)
    expect(JobTrainingActivity.count).to eq(0)
  end
end
