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

  describe ".pre_populated_drafts" do
    it "returns only pre-populated draft records" do
      pre_populated_draft = create(:volunteering_activity, :pre_populated_draft, activity_flow: flow)
      create(:volunteering_activity, activity_flow: flow, draft: true, pre_populated: false)
      create(:volunteering_activity, activity_flow: flow, draft: false, pre_populated: true)

      expect(flow.volunteering_activities.pre_populated_drafts).to contain_exactly(pre_populated_draft)
    end
  end

  describe "#publish!" do
    it "sets draft to false" do
      activity = create(:volunteering_activity, activity_flow: flow, draft: true)

      activity.publish!

      expect(activity.reload.draft).to be(false)
    end
  end

  describe "#pre_populated_draft?" do
    it "returns true only for a pre-populated draft record" do
      expect(build(:volunteering_activity, activity_flow: flow, draft: true, pre_populated: true)).to be_pre_populated_draft
      expect(build(:volunteering_activity, activity_flow: flow, draft: false, pre_populated: true)).not_to be_pre_populated_draft
      expect(build(:volunteering_activity, activity_flow: flow, draft: true, pre_populated: false)).not_to be_pre_populated_draft
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

  describe "activity type subclass contract" do
    ActivityFlowInvitation::ACTIVITY_TYPES.each do |type, klass|
      context "#{klass}" do
        it "defines FIELDS and PRE_POPULATED_REQUIRED_FIELDS (a subset of FIELDS)" do
          expect(klass::FIELDS).to be_an(Array)
          expect(klass::PRE_POPULATED_REQUIRED_FIELDS).to be_an(Array)
          expect(klass::FIELDS).to include(*klass::PRE_POPULATED_REQUIRED_FIELDS)
        end

        it "defines a Symbol .activity_type" do
          expect(klass.activity_type).to be_a(Symbol)
        end

        it "resolves .flow_association to an ActivityFlow association matching its registered type" do
          expect(ActivityFlow.reflect_on_association(klass.flow_association)).to be_present
          expect(klass.flow_association).to eq(:"#{type}_activities")
        end
      end
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
