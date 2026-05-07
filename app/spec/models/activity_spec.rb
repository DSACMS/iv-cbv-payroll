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
end
