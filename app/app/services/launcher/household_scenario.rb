class Launcher::HouseholdScenario
  REFERENCE_ID = "household-scenario"
  ARCHETYPES = {
    "needs_documentation_one_activity" => {
      reference_id: "dominic",
      display_name: "Dominic Santos",
      date_of_birth: Date.new(1985, 4, 12),
      activities: [
        { type: "employment", employer_name: "Acme Corp", hours: 70, gross_income: 1_680 },
        { type: "volunteering", organization_name: "Community Food Bank", hours: 15 }
      ]
    },
    "needs_documentation_multiple_activities" => {
      reference_id: "lamine",
      display_name: "Lamine Santos",
      date_of_birth: Date.new(1990, 9, 3),
      activities: [
        { type: "job_training", program_name: "Career Prep", organization_name: "Goodwill", hours: 50 },
        { type: "volunteering", organization_name: "Community Food Bank", hours: 35 }
      ]
    },
    "short_of_meeting_ce" => {
      reference_id: "andy",
      display_name: "Andy Santos",
      date_of_birth: Date.new(1995, 1, 18),
      activities: [
        { type: "employment", employer_name: "Acme Corp", hours: 31.5, gross_income: 756 }
      ]
    },
    "clean_slate" => {
      reference_id: "carlos",
      display_name: "Carlos Santos",
      date_of_birth: Date.new(2002, 6, 27),
      activities: []
    }
  }.freeze

  def self.archetypes
    ARCHETYPES
  end

  def self.default_archetype_keys
    ARCHETYPES.keys.first(2)
  end

  def self.create!(archetype_keys:, client_agency_id: "sandbox", launcher_overrides: {})
    new(archetype_keys:, client_agency_id:, launcher_overrides:).create!
  end

  def initialize(archetype_keys:, client_agency_id:, launcher_overrides:)
    @archetype_keys = Array(archetype_keys).filter_map(&:presence).uniq
    @client_agency_id = client_agency_id
    @launcher_overrides = launcher_overrides.to_h.stringify_keys
    @household_reference_id = "#{REFERENCE_ID}-#{@archetype_keys.join("-")}-#{client_agency_id}-#{SecureRandom.hex(4)}"
  end

  def create!
    raise ArgumentError, "At least one household archetype is required" if archetype_keys.empty?

    Household.transaction do
      household = Household.create!(
        reference_id: household_reference_id,
        client_agency_id: client_agency_id,
        launcher_overrides: launcher_overrides
      )

      archetype_keys.each_with_index do |archetype_key, index|
        member_data = archetype(archetype_key)
        invitation = create_invitation(member_data)
        household.household_members.create!(
          reference_id: member_data.fetch(:reference_id),
          activity_flow_invitation: invitation,
          display_name: member_data.fetch(:display_name),
          role_label: index.zero? ? "Primary applicant" : "Household member"
        )
      end

      household
    end
  end

  private

  attr_reader :archetype_keys, :client_agency_id, :household_reference_id, :launcher_overrides

  def archetype(key)
    ARCHETYPES.fetch(key)
  end

  def create_invitation(member_data)
    ActivityFlowInvitation.create!(
      reference_id: "#{household_reference_id}-#{member_data.fetch(:reference_id)}",
      client_agency_id: client_agency_id,
      cbv_applicant: create_applicant(member_data),
      pre_populated_activities: pre_populated_activities(member_data),
      skip_month_window_validation: true
    )
  end

  def pre_populated_activities(member_data)
    member_data.fetch(:activities).map do |activity|
      activity.slice(:type, :employer_name, :organization_name, :school_name, :program_name)
        .compact
        .stringify_keys
        .merge("months" => reporting_months.map { |month| activity_month(activity, month) })
    end
  end

  def reporting_months
    @reporting_months ||= begin
      range = ActivityFlow.expected_reporting_window_range(
        client_agency_id,
        reporting_window_type: launcher_overrides.fetch("reporting_window", "application"),
        reference_date: reporting_window_reference_date,
        months_override: reporting_window_month_count
      )
      months = []
      current = range.begin
      while current <= range.end
        months << current.iso8601
        current = current.next_month
      end
      months
    end
  end

  def activity_month(activity, month)
    activity.slice(:hours, :gross_income).compact.stringify_keys.merge("month" => month)
  end

  def reporting_window_month_count
    return launcher_overrides.fetch("reporting_window_months").to_i if launcher_overrides["reporting_window_months"].present?
    return ActivityFlow::DEFAULT_RENEWAL_REPORTING_WINDOW_MONTHS if launcher_overrides["reporting_window"] == "renewal"

    Rails.application.config.client_agencies[client_agency_id]&.application_reporting_months ||
      ActivityFlow::DEFAULT_APPLICATION_REPORTING_WINDOW_MONTHS
  end

  def reporting_window_reference_date
    return Date.current if launcher_overrides["reporting_window_start"].blank?

    Date.parse(launcher_overrides.fetch("reporting_window_start")) + reporting_window_month_count.months
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
