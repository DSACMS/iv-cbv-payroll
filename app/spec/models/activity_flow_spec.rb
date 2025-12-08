require 'rails_helper'

RSpec.describe ActivityFlow, type: :model do
  it "cleans up related volunteering activities when destroyed" do
    flow = create(:activity_flow)

    expect { flow.destroy }
      .to change { VolunteeringActivity.count }.by(-flow.volunteering_activities.count)
      .and change { JobTrainingActivity.count }.by(-flow.job_training_activities.count)
      .and change { EducationActivity.count }.by(-flow.education_activities.count)
  end

  describe "Education Activities" do
    let(:activity_flow) {
      create(
        :activity_flow,
        education_activities_count: 0
      )
    }

    let(:education_activities) {
      activity_flow.education_activities.create!(
        [
          attributes_for(:education_activity, confirmed: true),
          attributes_for(:education_activity, confirmed: false)
        ]
      )
    }

    describe "#education_activities" do
      it 'returns confirmed education activities' do
        expect(
          activity_flow.education_activities
        ).to match_array(
               education_activities.select(&:confirmed)
             )
      end
    end
  end

  it "belongs to a CBV applicant" do
    cbv_applicant = create(:cbv_applicant)
    activity_flow = create(:activity_flow, cbv_applicant: cbv_applicant)

    expect(activity_flow.cbv_applicant).to eq(cbv_applicant)
  end
end
