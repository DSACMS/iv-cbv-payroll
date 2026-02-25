require 'rails_helper'

RSpec.describe JobTrainingActivity, type: :model do
  it "stores work program organization and contact details" do
    activity = create(:job_training_activity,
      organization_name: "Goodwill",
      program_name: "Resume Workshop",
      street_address: "123 Main St",
      street_address_line_2: "Suite 5",
      city: "Baton Rouge",
      state: "LA",
      zip_code: "70802",
      contact_name: "Casey Doe",
      contact_email: "casey@example.com",
      contact_phone_number: "555-555-1234"
    )

    expect(activity.organization_name).to eq("Goodwill")
    expect(activity.program_name).to eq("Resume Workshop")
    expect(activity.street_address).to eq("123 Main St")
    expect(activity.street_address_line_2).to eq("Suite 5")
    expect(activity.city).to eq("Baton Rouge")
    expect(activity.state).to eq("LA")
    expect(activity.zip_code).to eq("70802")
    expect(activity.contact_name).to eq("Casey Doe")
    expect(activity.contact_email).to eq("casey@example.com")
    expect(activity.contact_phone_number).to eq("555-555-1234")
    expect(activity.date).to be_present
  end

  describe "date validation" do
    let(:activity_flow) { create(:activity_flow, reporting_window_months: 1, job_training_activities_count: 0) }

    it "is valid when date is within reporting window" do
      activity = create(:job_training_activity, activity_flow: activity_flow)

      expect(activity).to be_persisted
    end

    it "is invalid when date is outside reporting window" do
      activity = build(:job_training_activity, activity_flow: activity_flow, date: activity_flow.reporting_window_range.end + 1.day)

      expect(activity).not_to be_valid
      expect(activity.errors[:date]).to be_present
    end
  end

  describe "name validations" do
    let(:activity_flow) { create(:activity_flow, reporting_window_months: 1, job_training_activities_count: 0) }

    it "is invalid without an organization name" do
      activity = build(:job_training_activity, activity_flow: activity_flow, organization_name: nil)

      expect(activity).not_to be_valid
      expect(activity.errors[:organization_name]).to include("Enter the organization or provider name.")
    end

    it "is invalid without a program name" do
      activity = build(:job_training_activity, activity_flow: activity_flow, program_name: nil)

      expect(activity).not_to be_valid
      expect(activity.errors[:program_name]).to include("Enter the program name.")
    end
  end
end
