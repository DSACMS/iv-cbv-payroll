require 'rails_helper'

RSpec.describe ActivityFlow, type: :model do
  it "cleans up related volunteering activities when destroyed" do
    flow = create(:activity_flow)

    expect { flow.destroy }
      .to change(VolunteeringActivity, :count).by(-flow.volunteering_activities.count)
      .and change(JobTrainingActivity, :count).by(-flow.job_training_activities.count)
      .and change(EducationActivity, :count).by(-EducationActivity.where(activity_flow_id: flow.id).count)
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

  describe ".create_from_invitation" do
    let(:device_id) { "device123" }

    it "creates a flow from an invitation" do
      invitation = create(:activity_flow_invitation)

      flow = described_class.create_from_invitation(invitation, device_id)

      expect(flow).to be_persisted
      expect(flow.activity_flow_invitation).to eq(invitation)
      expect(flow.device_id).to eq(device_id)
      expect(flow.cbv_applicant).to be_present
    end

    it "uses invitation's cbv_applicant if present" do
      cbv_applicant = create(:cbv_applicant)
      invitation = create(:activity_flow_invitation, cbv_applicant: cbv_applicant)

      flow = described_class.create_from_invitation(invitation, device_id)

      expect(flow.cbv_applicant).to eq(cbv_applicant)
    end

    it "copies reporting_month from invitation" do
      invitation = create(:activity_flow_invitation, reporting_month: Date.new(2025, 3, 1))

      flow = described_class.create_from_invitation(invitation, device_id)

      expect(flow.reporting_month).to eq(invitation.reporting_month)
    end
  end

  describe "reporting_month" do
    it "defaults to the current month on create" do
      flow = create(:activity_flow, reporting_month: nil)

      expect(flow.reporting_month).to eq(Date.current.beginning_of_month)
    end

    it "returns a range for the month" do
      reporting_month = Date.new(2025, 2, 1)
      flow = build(:activity_flow, reporting_month: reporting_month)

      expect(flow.reporting_month_range).to eq(reporting_month.beginning_of_month..reporting_month.end_of_month)
    end

    it "returns a formatted display string" do
      flow = build(:activity_flow, reporting_month: Date.new(2025, 2, 1))

      expect(flow.reporting_month_display).to eq("February 2025")
    end
  end

  it 'marked as complete when completed_at timestamp is set' do
    flow = create(:activity_flow, completed_at: nil)
    expect(flow).not_to be_complete

    flow.update(completed_at: Time.current)
    expect(flow).to be_complete
  end
end
