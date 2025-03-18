class CbvApplicant < ApplicationRecord
  attr_accessor :caseworker_invitation
  # We use Single-Table Inheritance (STI) to create subclasses of this table
  # logic to process subsets of the columns of this model relevant to each
  # partner agency.
  #
  # The subclass is automatically instantiated by setting `client_agency_id`.
  # For example, `client_agency_id = "ma"` will result in instantiating an
  # instance of the CbvApplicant::Ma subclass, which contains all of its
  # indexing data validations.
  self.inheritance_column = "client_agency_id"

  def self.sti_name
    # "CbvApplicant::Ma" => "ma"
    name.demodulize.downcase
  end

  def self.sti_class_for(type_name)
    # "ma" => CbvApplicant::Ma
    CbvApplicant.const_get(type_name.capitalize)
  end

  PAYSTUB_REPORT_RANGE = 90.days

  has_many :cbv_flows
  has_many :cbv_flow_invitations

  before_validation :parse_snap_application_date
  validates :client_agency_id, presence: true

  include Redactable
  has_redactable_fields(
    first_name: :string,
    middle_name: :string,
    last_name: :string,
    client_id_number: :string,
    case_number: :string,
    agency_id_number: :string,
    beacon_id: :string,
    snap_application_date: :date
  )

  def paystubs_query_begins_at
    PAYSTUB_REPORT_RANGE.before(snap_application_date)
  end

  def parse_snap_application_date
    raw_snap_application_date = @attributes["snap_application_date"]&.value_before_type_cast
    return if raw_snap_application_date.is_a?(Date)
    # return if raw_snap_application_date.nil? and self.caseworker_invitation

    if raw_snap_application_date.is_a?(ActiveSupport::TimeWithZone) || raw_snap_application_date.is_a?(Time)
      self.snap_application_date = raw_snap_application_date.to_date
      # handle ISO 8601 date format, e.g. "2021-01-01" which is Ruby's default when querying a date field
    elsif raw_snap_application_date.is_a?(String) && raw_snap_application_date.match?(/^\d{4}-\d{2}-\d{2}$/)
      self.snap_application_date = Date.parse(raw_snap_application_date)
    else
      begin
        new_date_format = Date.strptime(raw_snap_application_date.to_s, "%m/%d/%Y")
        self.snap_application_date = new_date_format
      rescue Date::Error
        errors.add(:snap_application_date, :invalid_date) if self.caseworker_invitation
      end
    end

    self.snap_application_date ||= Time.current unless self.caseworker_invitation
  end
end
