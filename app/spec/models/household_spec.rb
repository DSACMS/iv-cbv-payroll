require "rails_helper"

RSpec.describe Household, type: :model do
  let(:household) { create(:household) }

  it "has a tokenized household URL" do
    expect(household.to_url(host: "example.test")).to eq("http://example.test/households/start/#{household.auth_token}")
  end

  it "has household members" do
    member = create(:household_member, household: household)

    expect(household.household_members).to contain_exactly(member)
  end

  it "requires a reference id" do
    household = build(:household, reference_id: nil)

    expect(household).not_to be_valid
    expect(household.errors[:reference_id]).to include("can't be blank")
  end

  it "requires a unique reference id" do
    existing_household = create(:household)
    household = build(:household, reference_id: existing_household.reference_id)

    expect(household).not_to be_valid
    expect(household.errors[:reference_id]).to include("has already been taken")
  end

  it "requires a known client agency" do
    household = build(:household, client_agency_id: "not_an_agency")

    expect(household).not_to be_valid
    expect(household.errors[:client_agency_id]).to include("is not included in the list")
  end
end
