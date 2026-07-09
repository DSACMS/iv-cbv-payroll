class Launcher::HouseholdScenario
  REFERENCE_ID = "household-scenario"
  MEMBERS = [
    {
      reference_id: "avery",
      display_name: "Avery Johnson",
      role_label: "Primary applicant",
      date_of_birth: Date.new(1985, 4, 12)
    },
    {
      reference_id: "riley",
      display_name: "Riley Johnson",
      role_label: "Household member",
      date_of_birth: Date.new(2004, 9, 3)
    }
  ].freeze

  def self.create_demo_household!(client_agency_id: "sandbox")
    new(client_agency_id).create_demo_household!
  end

  def initialize(client_agency_id)
    @client_agency_id = client_agency_id
    @household_reference_id = "#{REFERENCE_ID}-#{client_agency_id}-#{SecureRandom.hex(4)}"
  end

  def create_demo_household!
    Household.transaction do
      household = Household.create!(
        reference_id: household_reference_id,
        client_agency_id: client_agency_id
      )

      MEMBERS.each do |member_data|
        invitation = create_invitation(member_data)
        household.household_members.create!(
          reference_id: member_data.fetch(:reference_id),
          activity_flow_invitation: invitation,
          display_name: member_data.fetch(:display_name),
          role_label: member_data.fetch(:role_label)
        )
      end

      household
    end
  end

  private

  attr_reader :client_agency_id, :household_reference_id

  def create_invitation(member_data)
    ActivityFlowInvitation.create!(
      reference_id: "#{household_reference_id}-#{member_data.fetch(:reference_id)}",
      client_agency_id: client_agency_id,
      cbv_applicant: create_applicant(member_data)
    )
  end

  def create_applicant(member_data)
    CbvApplicant.create!(
      client_agency_id: client_agency_id,
      first_name: member_data.fetch(:display_name).split.first,
      last_name: member_data.fetch(:display_name).split.last,
      date_of_birth: member_data.fetch(:date_of_birth),
      snap_application_date: Date.current
    )
  end
end
