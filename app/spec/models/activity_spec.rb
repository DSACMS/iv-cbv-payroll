require "rails_helper"

RSpec.describe Activity do
  # Activity is abstract; test via VolunteeringActivity
  let(:flow) {
    create(:activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0)
  }

  describe ".published" do
    it "returns only non-draft records" do
      published = create(:volunteering_activity, activity_flow: flow, draft: false)
      _draft = create(:volunteering_activity, activity_flow: flow, draft: true)

      expect(flow.volunteering_activities.published).to contain_exactly(published)
    end
  end

  describe "#publish!" do
    it "sets draft to false" do
      activity = create(:volunteering_activity, activity_flow: flow, draft: true)

      activity.publish!

      expect(activity.reload.draft).to be(false)
    end
  end

  describe "#manual_education_upload?" do
    it "returns false for other activities" do
      expect(VolunteeringActivity.new).not_to be_manual_education_upload
    end
  end

  describe ".activity_type" do
    it "raises NotImplementedError on the abstract base" do
      expect { described_class.activity_type }.to raise_error(NotImplementedError)
    end
  end

  describe "monthly activity subclass contract" do
    it "links employment to its monthly record class" do
      expect(EmploymentActivity.activity_months_class).to eq(EmploymentActivityMonth)
    end

    it "links volunteering to its monthly record class" do
      expect(VolunteeringActivity.activity_months_class).to eq(VolunteeringActivityMonth)
    end

    it "links job training to its monthly record class" do
      expect(JobTrainingActivity.activity_months_class).to eq(JobTrainingActivityMonth)
    end
  end
end
