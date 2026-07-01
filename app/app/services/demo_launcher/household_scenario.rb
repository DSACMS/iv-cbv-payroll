class DemoLauncher::HouseholdScenario
  REFERENCE_ID = "demo-household-v1"
  MEMBERS = [
    {
      reference_id: "avery",
      display_name: "Avery Johnson",
      role_label: "Parent",
      date_of_birth: Date.new(1985, 4, 12)
    },
    {
      reference_id: "riley",
      display_name: "Riley Johnson",
      role_label: "Child",
      date_of_birth: Date.new(2004, 9, 3)
    }
  ].freeze

  def self.find_or_create!(client_agency_id: "sandbox")
    new(client_agency_id).find_or_create!
  end

  def initialize(client_agency_id)
    @client_agency_id = client_agency_id
  end

  def find_or_create!
    Household.transaction do
      household = Household.find_or_create_by!(reference_id: household_reference_id) do |record|
        record.client_agency_id = client_agency_id
      end

      MEMBERS.each do |member_data|
        invitation = find_or_create_invitation(member_data)
        member = household.household_members.find_or_initialize_by(reference_id: member_data.fetch(:reference_id))
        member.update!(
          activity_flow_invitation: invitation,
          display_name: member_data.fetch(:display_name),
          role_label: member_data.fetch(:role_label)
        )
      end

      household
    end
  end

  private

  attr_reader :client_agency_id

  def household_reference_id
    "#{REFERENCE_ID}-#{client_agency_id}"
  end

  def find_or_create_invitation(member_data)
    ActivityFlowInvitation.find_or_create_by!(reference_id: "#{household_reference_id}-#{member_data.fetch(:reference_id)}") do |invitation|
      invitation.client_agency_id = client_agency_id
      invitation.cbv_applicant = create_applicant(member_data)
    end
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
