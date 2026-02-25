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
    let(:placeholder) { "N/A" }

    it "stores placeholder when self-employed" do
      activity = create(:employment_activity,
        is_self_employed: true,
        contact_name: placeholder,
        contact_email: placeholder,
        contact_phone_number: placeholder
      )

      expect(activity.is_self_employed).to be true
      expect(activity.contact_name).to eq(placeholder)
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
