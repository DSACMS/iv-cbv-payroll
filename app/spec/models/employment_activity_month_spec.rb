require "rails_helper"

RSpec.describe EmploymentActivityMonth, type: :model do
  it_behaves_like "an activity month model",
    parent_factory: :employment_activity,
    month_factory: :employment_activity_month,
    parent_association: :employment_activity

  describe "gross_income validations" do
    let(:activity) { create(:employment_activity) }

    it "is valid with zero gross income" do
      month_record = build(:employment_activity_month, employment_activity: activity, gross_income: 0)
      expect(month_record).to be_valid
    end

    it "is invalid with negative gross income" do
      month_record = build(:employment_activity_month, employment_activity: activity, gross_income: -1)
      expect(month_record).not_to be_valid
      expect(month_record.errors[:gross_income]).to be_present
    end

    it "is invalid with non-integer gross income" do
      month_record = build(:employment_activity_month, employment_activity: activity, gross_income: 2.5)
      expect(month_record).not_to be_valid
      expect(month_record.errors[:gross_income]).to be_present
    end
  end
end
