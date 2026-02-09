require "rails_helper"

RSpec.describe ActivitiesHelper do
  describe "#any_activities_added?" do
    let(:empty_flow) do
      create(
        :activity_flow,
        volunteering_activities_count: 0,
        job_training_activities_count: 0,
        education_activities_count: 0
      )
    end

    it "returns false when flow has no activities" do
      expect(helper.any_activities_added?(empty_flow)).to be false
    end

    it "returns false when flow has an education activity without enrollment data" do
      create(:education_activity, activity_flow: empty_flow)

      expect(helper.any_activities_added?(empty_flow)).to be false
    end

    it "returns true when flow has an education activity with enrollment data" do
      education_activity = create(:education_activity, activity_flow: empty_flow)
      create(:nsc_enrollment_term, education_activity:)

      expect(helper.any_activities_added?(empty_flow)).to be true
    end

    [
      [ :volunteering_activity, :activity_flow ],
      [ :job_training_activity, :activity_flow ],
      [ :payroll_account, :flow ]
    ].each do |factory_name, flow_attribute|
      activity_name = factory_name.to_s.humanize.downcase

      it "returns true when flow includes #{activity_name}" do
        create(factory_name, flow_attribute => empty_flow)
        expect(helper.any_activities_added?(empty_flow)).to be true
      end
    end
  end
end
