require 'rails_helper'

RSpec.describe VolunteeringActivity, type: :model do
  it 'has fields for organization_name, date, and hours' do
    activity = create(:volunteering_activity, organization_name: "Daph's Fun House", hours: 2)

    expect(activity.organization_name).to eq("Daph's Fun House")
    expect(activity.date).to be_present
    expect(activity.hours).to eq(2)
  end

  describe "date validation" do
    let(:activity_flow) { create(:activity_flow, reporting_window_months: 1, volunteering_activities_count: 0) }

    it "is valid when date is within reporting window" do
      activity = create(:volunteering_activity, activity_flow: activity_flow)

      expect(activity).to be_persisted
    end

    it "is invalid when date is outside reporting window" do
      activity = build(:volunteering_activity, activity_flow: activity_flow, date: activity_flow.reporting_window_range.end + 1.day)

      expect(activity).not_to be_valid
      expect(activity.errors[:date]).to be_present
    end
  end

  describe "#formatted_address" do
    let(:base_address_attrs) do
      { street_address: "123 Main St", city: "Springfield", state: "Illinois", zip_code: "62701" }
    end

    it "joins street, city, state, and zip into a single line" do
      activity = create(:volunteering_activity, base_address_attrs)

      expect(activity.formatted_address).to eq("123 Main St, Springfield, Illinois 62701")
    end

    it "includes street_address_line_2 when present" do
      activity = create(:volunteering_activity, base_address_attrs.merge(street_address_line_2: "Suite 200"))

      expect(activity.formatted_address).to eq("123 Main St, Suite 200, Springfield, Illinois 62701")
    end
  end
end
