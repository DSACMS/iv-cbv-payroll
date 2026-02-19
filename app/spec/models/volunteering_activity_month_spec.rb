require "rails_helper"

RSpec.describe VolunteeringActivityMonth, type: :model do
  describe "associations" do
    it "belongs to a volunteering_activity" do
      month_record = create(:volunteering_activity_month)
      expect(month_record.volunteering_activity).to be_a(VolunteeringActivity)
    end
  end

  describe "validations" do
    let(:activity) { create(:volunteering_activity, organization_name: "Food Pantry") }

    it "is valid with a month and non-negative hours" do
      month_record = build(:volunteering_activity_month, volunteering_activity: activity, hours: 10)
      expect(month_record).to be_valid
    end

    it "is valid with zero hours" do
      month_record = build(:volunteering_activity_month, volunteering_activity: activity, hours: 0)
      expect(month_record).to be_valid
    end

    it "is invalid without a month" do
      month_record = build(:volunteering_activity_month, volunteering_activity: activity, month: nil)
      expect(month_record).not_to be_valid
      expect(month_record.errors[:month]).to be_present
    end

    it "is invalid with negative hours" do
      month_record = build(:volunteering_activity_month, volunteering_activity: activity, hours: -1)
      expect(month_record).not_to be_valid
      expect(month_record.errors[:hours]).to be_present
    end

    it "is invalid with non-integer hours" do
      month_record = build(:volunteering_activity_month, volunteering_activity: activity, hours: 2.5)
      expect(month_record).not_to be_valid
      expect(month_record.errors[:hours]).to be_present
    end
  end

  describe "dependent destroy" do
    it "is destroyed when the volunteering_activity is destroyed" do
      activity = create(:volunteering_activity, organization_name: "Food Pantry")
      create(:volunteering_activity_month, volunteering_activity: activity, hours: 10)

      expect { activity.destroy }.to change(described_class, :count).by(-1)
    end
  end
end
