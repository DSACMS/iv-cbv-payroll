require "rails_helper"

RSpec.describe HouseholdMember, type: :model do
  let(:household) { create(:household) }

  it "connects a household member to an activity flow invitation" do
    invitation = create(:activity_flow_invitation)
    member = create(:household_member, activity_flow_invitation: invitation)

    expect(member.activity_flow_invitation).to eq(invitation)
  end

  it "requires a member-specific activity flow invitation" do
    invitation = create(:activity_flow_invitation)
    create(:household_member, activity_flow_invitation: invitation)

    member = build(:household_member, activity_flow_invitation: invitation)

    expect(member).not_to be_valid
    expect(member.errors[:activity_flow_invitation_id]).to include("has already been taken")
  end

  it "requires display fields and a reference id" do
    member = build(:household_member, display_name: nil, role_label: nil, reference_id: nil)

    expect(member).not_to be_valid
    expect(member.errors[:display_name]).to include("can't be blank")
    expect(member.errors[:role_label]).to include("can't be blank")
    expect(member.errors[:reference_id]).to include("can't be blank")
  end

  it "requires a member reference id to be unique within the household" do
    create(:household_member, household: household, reference_id: "avery")

    member = build(:household_member, household: household, reference_id: "avery")

    expect(member).not_to be_valid
    expect(member.errors[:reference_id]).to include("has already been taken")
  end

  it "allows the same member reference id in different households" do
    create(:household_member, household: household, reference_id: "avery")

    member = build(:household_member, reference_id: "avery")

    expect(member).to be_valid
  end
end
