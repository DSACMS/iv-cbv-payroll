require 'rails_helper'

RSpec.describe ActivityFlowInvitation, type: :model do
  it "has many activity flows" do
    invitation = create(:activity_flow_invitation)
    flow1 = create(:activity_flow, activity_flow_invitation: invitation)
    flow2 = create(:activity_flow, activity_flow_invitation: invitation)

    expect(invitation.activity_flows).to contain_exactly(flow1, flow2)
  end

  it "generates a secure token on create" do
    invitation = create(:activity_flow_invitation)

    expect(invitation.auth_token).to be_present
    expect(invitation.auth_token.length).to eq(10)
  end

  describe "#to_url" do
    it "generates a URL with the auth token" do
      invitation = create(:activity_flow_invitation)

      expect(invitation.to_url).to include(invitation.auth_token)
      expect(invitation.to_url).to include("activities/start")
    end
  end

  describe "pre_populated_activities validation" do
    it "is valid with a well-formed volunteering entry" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        { "type" => "volunteering", "organization_name" => "Red Cross" }
      ])

      expect(invitation).to be_valid
    end

    it "is invalid when an entry has no organization_name" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        { "type" => "volunteering" }
      ])

      expect(invitation).not_to be_valid
      expect(invitation.errors.attribute_names.map(&:to_s))
        .to include("pre_populated_activities[0].organization_name")
    end

    it "is invalid when an entry has an unsupported type" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        { "type" => "knitting", "organization_name" => "Yarn Co" }
      ])

      expect(invitation).not_to be_valid
      expect(invitation.errors.attribute_names.map(&:to_s))
        .to include("pre_populated_activities[0].type")
    end

    it "is valid when pre_populated_activities is empty" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [])

      expect(invitation).to be_valid
    end

    it "is valid with a well-formed employment entry" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        { "type" => "employment", "employer_name" => "Acme Corp" }
      ])

      expect(invitation).to be_valid
    end

    it "is invalid when an employment entry is missing employer_name" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        { "type" => "employment" }
      ])

      expect(invitation).not_to be_valid
      expect(invitation.errors.attribute_names.map(&:to_s))
        .to include("pre_populated_activities[0].employer_name")
    end

    it "is valid with a well-formed education entry" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        { "type" => "education", "school_name" => "Springfield Community College" }
      ])

      expect(invitation).to be_valid
    end

    it "is invalid when an education entry is missing school_name" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        { "type" => "education" }
      ])

      expect(invitation).not_to be_valid
      expect(invitation.errors.attribute_names.map(&:to_s))
        .to include("pre_populated_activities[0].school_name")
    end

    it "is valid with a well-formed job training entry" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        { "type" => "job_training", "program_name" => "Career Prep", "organization_name" => "Goodwill" }
      ])

      expect(invitation).to be_valid
    end

    it "is invalid when a job training entry is missing program_name" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        { "type" => "job_training", "organization_name" => "Goodwill" }
      ])

      expect(invitation).not_to be_valid
      expect(invitation.errors.attribute_names.map(&:to_s))
        .to include("pre_populated_activities[0].program_name")
    end

    it "is invalid when a job training entry is missing organization_name" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        { "type" => "job_training", "program_name" => "Career Prep" }
      ])

      expect(invitation).not_to be_valid
      expect(invitation.errors.attribute_names.map(&:to_s))
        .to include("pre_populated_activities[0].organization_name")
    end
  end

  describe "month-in-window validation" do
    let(:in_window_date) { ActivityFlow.expected_reporting_window_range("sandbox").end.iso8601 }
    let(:out_of_window_date) { (Date.current + 60.days).iso8601 }

    it "is valid when months fall within the expected reporting window" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        {
          "type" => "volunteering",
          "organization_name" => "Red Cross",
          "months" => [ { "month" => in_window_date, "hours" => 4 } ]
        }
      ])

      expect(invitation).to be_valid
    end

    it "is invalid when a month falls outside the expected reporting window" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        {
          "type" => "volunteering",
          "organization_name" => "Red Cross",
          "months" => [ { "month" => out_of_window_date, "hours" => 4 } ]
        }
      ])

      expect(invitation).not_to be_valid
      expect(invitation.errors.attribute_names.map(&:to_s))
        .to include("pre_populated_activities[0].months[0].month")
    end

    it "is invalid when a month value cannot be parsed as a date" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        {
          "type" => "volunteering",
          "organization_name" => "Red Cross",
          "months" => [ { "month" => "not-a-date", "hours" => 4 } ]
        }
      ])

      expect(invitation).not_to be_valid
      expect(invitation.errors.attribute_names.map(&:to_s))
        .to include("pre_populated_activities[0].months[0].month")
    end

    it "is valid when an employment entry's months fall within the expected reporting window" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        {
          "type" => "employment",
          "employer_name" => "Acme Corp",
          "months" => [ { "month" => in_window_date, "hours" => 40, "gross_income" => 3000 } ]
        }
      ])

      expect(invitation).to be_valid
    end

    it "is invalid when an employment entry's month falls outside the expected reporting window" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        {
          "type" => "employment",
          "employer_name" => "Acme Corp",
          "months" => [ { "month" => out_of_window_date, "hours" => 40, "gross_income" => 3000 } ]
        }
      ])

      expect(invitation).not_to be_valid
      expect(invitation.errors.attribute_names.map(&:to_s))
        .to include("pre_populated_activities[0].months[0].month")
    end

    it "is valid when an education entry's months fall within the expected reporting window" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        {
          "type" => "education",
          "school_name" => "Springfield Community College",
          "months" => [ { "month" => in_window_date, "hours" => 6 } ]
        }
      ])

      expect(invitation).to be_valid
    end

    it "is invalid when an education entry's month falls outside the expected reporting window" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        {
          "type" => "education",
          "school_name" => "Springfield Community College",
          "months" => [ { "month" => out_of_window_date, "hours" => 6 } ]
        }
      ])

      expect(invitation).not_to be_valid
      expect(invitation.errors.attribute_names.map(&:to_s))
        .to include("pre_populated_activities[0].months[0].month")
    end

    it "is valid when a job training entry's months fall within the expected reporting window" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        {
          "type" => "job_training",
          "program_name" => "Career Prep",
          "organization_name" => "Goodwill",
          "months" => [ { "month" => in_window_date, "hours" => 10 } ]
        }
      ])

      expect(invitation).to be_valid
    end

    it "is invalid when a job training entry's month falls outside the expected reporting window" do
      invitation = build(:activity_flow_invitation, pre_populated_activities: [
        {
          "type" => "job_training",
          "program_name" => "Career Prep",
          "organization_name" => "Goodwill",
          "months" => [ { "month" => out_of_window_date, "hours" => 10 } ]
        }
      ])

      expect(invitation).not_to be_valid
      expect(invitation.errors.attribute_names.map(&:to_s))
        .to include("pre_populated_activities[0].months[0].month")
    end
  end
end
