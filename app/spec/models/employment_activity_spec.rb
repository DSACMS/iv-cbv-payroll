require "rails_helper"

RSpec.describe EmploymentActivity, type: :model do
  it "has fields for employer information" do
    activity = create(:employment_activity, employer_name: "Acme Corp")

    expect(activity.employer_name).to eq("Acme Corp")
    expect(activity.data_source).to eq("self_attested")
  end

  it "belongs to an activity flow" do
    activity = create(:employment_activity)

    expect(activity.activity_flow).to be_present
  end

  describe "self-employed contact information" do
    it "clears contact fields when self-employed" do
      activity = create(:employment_activity,
        is_self_employed: true,
        contact_name: "N/A",
        contact_email: "N/A",
        contact_phone_number: "N/A"
      )

      expect(activity.is_self_employed).to be true
      expect(activity.contact_name).to be_nil
      expect(activity.contact_email).to be_nil
      expect(activity.contact_phone_number).to be_nil
    end
  end

  describe "#formatted_address" do
    let(:base_address_attrs) do
      attributes_for(:employment_activity).slice(:street_address, :city, :state, :zip_code)
    end

    it "joins street, city, state, and zip into a single line" do
      activity = create(:employment_activity, base_address_attrs)

      expect(activity.formatted_address).to eq("942 W Harlan Ave, Gainesville, FL 32611")
    end

    it "includes street_address_line_2 when present" do
      activity = create(:employment_activity, base_address_attrs.merge(street_address_line_2: "Suite 100"))

      expect(activity.formatted_address).to eq("942 W Harlan Ave, Suite 100, Gainesville, FL 32611")
    end

    it "handles missing fields" do
      activity = create(:employment_activity, street_address: nil, city: nil, state: nil, zip_code: nil)

      expect(activity.formatted_address).to eq("")
    end
  end
end
