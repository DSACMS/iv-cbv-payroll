require "rails_helper"

RSpec.describe DemoLauncher::HouseholdScenario do
  describe ".find_or_create!" do
    it "creates a test household with two members and member invitations" do
      household = described_class.find_or_create!(client_agency_id: "sandbox")

      expect(household.client_agency_id).to eq("sandbox")
      expect(household.household_members.map(&:display_name)).to contain_exactly("Avery Johnson", "Riley Johnson")
      expect(household.household_members.map(&:role_label)).to contain_exactly("Parent", "Child")
      invitations = household.household_members.map(&:activity_flow_invitation)
      expect(invitations).to all(be_present)
      expect(invitations.uniq.size).to eq(invitations.size)
      expect(invitations.map(&:cbv_applicant)).to all(be_present)
      expect(invitations.map(&:cbv_applicant).uniq.size).to eq(invitations.size)
    end

    it "reuses the same household and members" do
      household = described_class.find_or_create!(client_agency_id: "sandbox")
      counts = {
        households: Household.count,
        household_members: HouseholdMember.count,
        activity_flow_invitations: ActivityFlowInvitation.count,
        cbv_applicants: CbvApplicant.count
      }

      same_household = described_class.find_or_create!(client_agency_id: "sandbox")

      expect(same_household).to eq(household)
      expect(Household.count).to eq(counts.fetch(:households))
      expect(HouseholdMember.count).to eq(counts.fetch(:household_members))
      expect(ActivityFlowInvitation.count).to eq(counts.fetch(:activity_flow_invitations))
      expect(CbvApplicant.count).to eq(counts.fetch(:cbv_applicants))
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
        household = described_class.find_or_create!(client_agency_id: "sandbox")
      }.to change(CbvApplicant, :count).by(2)

      avery_member = household.household_members.find_by!(reference_id: "avery")

      expect(avery_member.activity_flow_invitation.cbv_applicant).to have_attributes(
        first_name: "Avery",
        last_name: "Johnson",
        date_of_birth: Date.new(1985, 4, 12)
      )
    end

    it "creates separate test households per agency" do
      sandbox_household = described_class.find_or_create!(client_agency_id: "sandbox")
      la_household = described_class.find_or_create!(client_agency_id: "la_ldh")

      expect(la_household).not_to eq(sandbox_household)
      expect(la_household.reference_id).not_to eq(sandbox_household.reference_id)
      sandbox_invitations = sandbox_household.household_members.map(&:activity_flow_invitation)
      la_invitations = la_household.household_members.map(&:activity_flow_invitation)
      expect(la_invitations & sandbox_invitations).to be_empty
    end
  end
end
