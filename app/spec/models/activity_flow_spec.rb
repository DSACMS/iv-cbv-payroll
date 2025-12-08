require 'rails_helper'

RSpec.describe ActivityFlow, type: :model do
  describe ".create_with_token" do
    it "generates a token automatically" do
      flow = ActivityFlow.create_with_token
      expect(flow.token).to be_present
    end

    it "stores the reference_id when provided" do
      flow = ActivityFlow.create_with_token(reference_id: "case_123")
      expect(flow.reference_id).to eq("case_123")
    end
  end

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

  it "belongs to a CBV applicant" do
    cbv_applicant = create(:cbv_applicant)
    activity_flow = create(:activity_flow, cbv_applicant: cbv_applicant)

    expect(activity_flow.cbv_applicant).to eq(cbv_applicant)
  end
end
