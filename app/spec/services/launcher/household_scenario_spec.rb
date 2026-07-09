require "rails_helper"

RSpec.describe Launcher::HouseholdScenario do
  describe ".create_demo_household!" do
    it "creates a test household with two members and member invitations" do
      household = described_class.create_demo_household!(client_agency_id: "sandbox")

      expect(household.client_agency_id).to eq("sandbox")
      expect(household.reference_id).to start_with("household-scenario-sandbox-")
      expect(household.household_members.map(&:display_name)).to contain_exactly("Avery Johnson", "Riley Johnson")
      expect(household.household_members.map(&:role_label)).to contain_exactly("Primary applicant", "Household member")
      invitations = household.household_members.map(&:activity_flow_invitation)
      expect(invitations).to all(be_present)
      expect(invitations.uniq.size).to eq(invitations.size)
      expect(invitations.map(&:cbv_applicant)).to all(be_present)
      expect(invitations.map(&:cbv_applicant).uniq.size).to eq(invitations.size)
    end

    it "creates a fresh test household each time" do
      household = described_class.create_demo_household!(client_agency_id: "sandbox")

      expect {
        described_class.create_demo_household!(client_agency_id: "sandbox")
      }.to change(Household, :count).by(1)
        .and change(HouseholdMember, :count).by(2)
        .and change(ActivityFlowInvitation, :count).by(2)
        .and change(CbvApplicant, :count).by(2)

      expect(Household.last).not_to eq(household)
    end

    it "does not reuse an existing applicant that matches a member's name and date of birth" do
      create(
        :cbv_applicant,
        client_agency_id: "sandbox",
        first_name: "Avery",
        last_name: "Johnson",
        date_of_birth: Date.new(1985, 4, 12)
      )

      household = nil
      expect {
        household = described_class.create_demo_household!(client_agency_id: "sandbox")
      }.to change(CbvApplicant, :count).by(2)

      avery_member = household.household_members.find_by!(reference_id: "avery")

      expect(avery_member.activity_flow_invitation.cbv_applicant).to have_attributes(
        first_name: "Avery",
        last_name: "Johnson",
        date_of_birth: Date.new(1985, 4, 12)
      )
    end

    it "creates separate test households per agency" do
      sandbox_household = described_class.create_demo_household!(client_agency_id: "sandbox")
      la_household = described_class.create_demo_household!(client_agency_id: "la_ldh")

      expect(la_household).not_to eq(sandbox_household)
      expect(la_household.reference_id).not_to eq(sandbox_household.reference_id)
      sandbox_invitations = sandbox_household.household_members.map(&:activity_flow_invitation)
      la_invitations = la_household.household_members.map(&:activity_flow_invitation)
      expect(la_invitations & sandbox_invitations).to be_empty
    end
  end
end
