class CbvApplicant < ApplicationRecord
  include Redactable

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

  validates :client_agency_id, presence: true

  # validate that the date_of_birth is in the past
  validates :date_of_birth, comparison: {
    less_than_or_equal_to: Date.current,
     message: :future_date
  }, if: -> { is_applicant_attribute_required?(:date_of_birth) && date_of_birth.present? }

  # validate that the date_of_birth is not more than 110 years ago
  validates :date_of_birth, comparison: {
    greater_than_or_equal_to: 110.years.ago.to_date,
    message: :invalid_date
  }, if: -> { is_applicant_attribute_required?(:date_of_birth) && date_of_birth.present? }

  validates :snap_application_date, presence: {
    message: :invalid_date
  }

  def date_of_birth=(value)
    self[:date_of_birth] = parse_date(value)
  end

  def snap_application_date=(value)
    self[:snap_application_date] = parse_date(value)
  end

  def has_applicant_attribute_missing?
    @required_applicant_attributes.any? do |attr|
      self[attr].nil?
    end
  end

  def validate_base_and_applicant_attributes?
    valid? && validate_required_applicant_attributes.empty?
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

    missing_attrs
  end

  def paystubs_query_begins_at
    PAYSTUB_REPORT_RANGE.before(snap_application_date)
  end

  def set_snap_application_date
    self.snap_application_date ||= Date.current
  end

  def set_applicant_attributes
    @applicant_attributes = Rails.application.config.client_agencies[client_agency_id]&.applicant_attributes&.compact&.keys&.map(&:to_sym) || []
    @required_applicant_attributes = get_required_applicant_attributes
  end

  def is_applicant_attribute_required?(attribute)
    get_required_applicant_attributes
    .include?(attribute)
  end

  private
  def parse_date(value)
    return value if value.is_a?(Date)

    if value.is_a?(String) && value.present?
      begin
        Date.strptime(value, "%m/%d/%Y")
      rescue ArgumentError
        nil
      end
    end
  end

  def get_required_applicant_attributes
    Rails.application.config.client_agencies[client_agency_id]&.applicant_attributes&.select { |key, attributes| attributes["required"] }&.keys&.map(&:to_sym) || []
  end
end
