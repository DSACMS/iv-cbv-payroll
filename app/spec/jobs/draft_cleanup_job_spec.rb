require "rails_helper"

RSpec.describe DraftCleanupJob do
  let(:flow) { create(:activity_flow) }

  it "deletes draft activities older than 24 hours" do
    old_draft = create(:volunteering_activity, activity_flow: flow, draft: true, created_at: 25.hours.ago)
    recent_draft = create(:volunteering_activity, activity_flow: flow, draft: true, created_at: 1.hour.ago)
    published = create(:volunteering_activity, activity_flow: flow, draft: false, created_at: 25.hours.ago)

    described_class.perform_now

    expect(VolunteeringActivity.exists?(old_draft.id)).to be(false)
    expect(VolunteeringActivity.exists?(recent_draft.id)).to be(true)
    expect(VolunteeringActivity.exists?(published.id)).to be(true)
  end

  it "deletes draft payroll accounts older than 24 hours" do
    old_draft = create(:payroll_account, :pinwheel_fully_synced, flow: flow, draft: true, created_at: 25.hours.ago)
    published = create(:payroll_account, :pinwheel_fully_synced, flow: flow, draft: false, created_at: 25.hours.ago)

    described_class.perform_now

    expect(PayrollAccount.exists?(old_draft.id)).to be(false)
    expect(PayrollAccount.exists?(published.id)).to be(true)
  end

  it "deletes drafts across all activity types" do
    old_volunteering = create(:volunteering_activity, activity_flow: flow, draft: true, created_at: 25.hours.ago)
    old_job_training = create(:job_training_activity, activity_flow: flow, draft: true, created_at: 25.hours.ago)
    old_employment = create(:employment_activity, activity_flow: flow, draft: true, created_at: 25.hours.ago)
    old_education = create(:education_activity, activity_flow: flow, draft: true, created_at: 25.hours.ago)

    described_class.perform_now

    expect(VolunteeringActivity.exists?(old_volunteering.id)).to be(false)
    expect(JobTrainingActivity.exists?(old_job_training.id)).to be(false)
    expect(EmploymentActivity.exists?(old_employment.id)).to be(false)
    expect(EducationActivity.exists?(old_education.id)).to be(false)
  end
end
