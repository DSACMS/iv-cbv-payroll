class CbvApplicant < ApplicationRecord
  after_initialize :set_snap_application_date, if: :new_record?
  after_initialize :set_applicant_attributes
  attr_reader :applicant_attributes, :required_applicant_attributes

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
    # "az_des" => CbvApplicant::AzDes
    CbvApplicant.const_get(type_name.camelize)
  end

  def self.valid_attributes_for_agency(client_agency_id)
    sti_class_for(client_agency_id).const_get(:VALID_ATTRIBUTES)
  end

  PAYSTUB_REPORT_RANGE = 90.days

  has_many :cbv_flows
  has_many :cbv_flow_invitations

  before_validation :parse_snap_application_date
  validates :client_agency_id, presence: true

  # validate that the date_of_birth is in the past
  validates :date_of_birth, comparison: {
    less_than: Date.current,
     message: :future_date
  }, if: -> { date_of_birth_required? && date_of_birth.present? }

  # validate that the date_of_birth is not more than 110 years ago
  validates :date_of_birth, comparison: {
    greater_than_or_equal_to: 110.years.ago.to_date,
    message: :invalid_date
  }, if: :date_of_birth_required?

  include Redactable
  has_redactable_fields(
    first_name: :string,
    middle_name: :string,
    last_name: :string,
    client_id_number: :string,
    case_number: :string,
    agency_id_number: :string,
    beacon_id: :string,
    snap_application_date: :date,
    date_of_birth: :date
  )

  def has_applicant_attribute_missing?
    @required_applicant_attributes.any? do |attr|
      self[attr].nil?
    end
  end

  def validate_required_applicant_attributes
    missing_attrs = @required_applicant_attributes.reject do |attr|
      self.send(attr).present?
    end

    if missing_attrs.any?
      missing_attrs.each do |attr|
        errors.add(attr, I18n.t("cbv.applicant_informations.#{client_agency_id}.fields.#{attr}.blank"))
      end
    end
  end

  def paystubs_query_begins_at
    PAYSTUB_REPORT_RANGE.before(snap_application_date)
  end

  def set_snap_application_date
    self.snap_application_date ||= Date.current
  end

  def parse_snap_application_date
    raw_snap_application_date = @attributes["snap_application_date"]&.value_before_type_cast
    return if raw_snap_application_date.is_a?(Date)

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
        errors.add(:snap_application_date, :invalid_date)
      end
    end
  end

  def set_applicant_attributes
    @applicant_attributes = Rails.application.config.client_agencies[client_agency_id]&.applicant_attributes&.compact&.keys&.map(&:to_sym) || []
    @required_applicant_attributes = Rails.application.config.client_agencies[client_agency_id]&.applicant_attributes&.select { |key, attributes| attributes["required"] }&.keys&.map(&:to_sym) || []
  end

  def date_of_birth_required?
    required_attrs = Rails.application.config.client_agencies[client_agency_id]&.applicant_attributes&.select { |key, attributes| attributes["required"] }&.keys&.map(&:to_sym) || []
    required_attrs.include?(:date_of_birth)
  end
end
