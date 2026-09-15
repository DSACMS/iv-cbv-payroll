require "rails_helper"

RSpec.describe Launcher::HouseholdScenario do
  describe ".create!" do
    let(:archetype_keys) { %w[needs_documentation_one_activity short_of_meeting_ce] }

    it "creates one member for each selected archetype" do
      household = described_class.create!(archetype_keys:, client_agency_id: "sandbox")

      expect(household.client_agency_id).to eq("sandbox")
      expect(household.reference_id).to start_with("household-scenario-needs_documentation_one_activity-short_of_meeting_ce-sandbox-")

      members = household.household_members.order(:id)
      expect(members.map(&:display_name)).to eq([ "Dominic Santos", "Andy Santos" ])
      expect(members.map(&:role_label)).to eq([ "Primary applicant", "Household member" ])

      invitations = members.map(&:activity_flow_invitation)
      expect(invitations).to all(be_present)
      expect(invitations.uniq.size).to eq(invitations.size)
      expect(invitations.map(&:cbv_applicant)).to all(be_present)
      expect(invitations.map(&:cbv_applicant).uniq.size).to eq(invitations.size)
    end

    it "creates a fresh household each time" do
      household = described_class.create!(archetype_keys:, client_agency_id: "sandbox")

      expect {
        described_class.create!(archetype_keys:, client_agency_id: "sandbox")
      }.to change(Household, :count).by(1)
        .and change(HouseholdMember, :count).by(2)
        .and change(ActivityFlowInvitation, :count).by(2)
        .and change(CbvApplicant, :count).by(2)

      expect(Household.last).not_to eq(household)
    end

    it "does not reuse an existing applicant that matches an archetype member" do
      create(
        :cbv_applicant,
        client_agency_id: "sandbox",
        first_name: "Dominic",
        last_name: "Santos",
        date_of_birth: Date.new(1985, 4, 12)
      )

      household = nil
      expect {
        household = described_class.create!(archetype_keys:, client_agency_id: "sandbox")
      }.to change(CbvApplicant, :count).by(2)

      dominic_member = household.household_members.find_by!(reference_id: "dominic")

      expect(dominic_member.activity_flow_invitation.cbv_applicant).to have_attributes(
        first_name: "Dominic",
        last_name: "Santos",
        date_of_birth: Date.new(1985, 4, 12)
      )
    end

    it "creates separate households per agency" do
      sandbox_household = described_class.create!(archetype_keys:, client_agency_id: "sandbox")
      research_household = described_class.create!(archetype_keys:, client_agency_id: "research")

      expect(research_household).not_to eq(sandbox_household)
      expect(research_household.reference_id).not_to eq(sandbox_household.reference_id)

      sandbox_invitations = sandbox_household.household_members.map(&:activity_flow_invitation)
      research_invitations = research_household.household_members.map(&:activity_flow_invitation)
      expect(research_invitations & sandbox_invitations).to be_empty
    end

    it "does not duplicate a selected archetype" do
      household = described_class.create!(
        archetype_keys: [ "clean_slate", "clean_slate" ],
        client_agency_id: "sandbox"
      )

      expect(household.household_members.map(&:reference_id)).to eq([ "carlos" ])
    end

    it "requires at least one archetype" do
      expect {
        described_class.create!(archetype_keys: [], client_agency_id: "sandbox")
      }.to raise_error(ArgumentError, "At least one household archetype is required")
    end
  end
end
