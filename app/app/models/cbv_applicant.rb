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
  # For example, `client_agency_id = "sandbox"` will result in instantiating an
  # instance of the CbvApplicant::Sandbox subclass, which contains all of its
  # indexing data validations.
  self.inheritance_column = "client_agency_id"

  def self.sti_name
    # "CbvApplicant::AzDes" => "az_des"
    name.demodulize.underscore
  end

  def self.sti_class_for(type_name)
    # "sandbox" => CbvApplicant::Sandbox
    CbvApplicant.const_get(type_name.camelize)
  end

  def self.valid_attributes_for_agency(client_agency_id)
    sti_class_for(client_agency_id).const_get(:VALID_ATTRIBUTES)
  end

  def self.build_agency_partner_metadata(client_agency_id, &value_provider)
    valid_attributes_for_agency(client_agency_id).each_with_object({}) do |attr, hash|
      hash[attr.to_s] = value_provider.call(attr)
    end
  end

  has_many :cbv_flows
  has_many :cbv_flow_invitations
  has_many :activity_flows

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
    self[:date_of_birth] = DateFormatter.parse(value)
  end

  def snap_application_date=(value)
    self[:snap_application_date] = DateFormatter.parse(value)
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

  def set_snap_application_date
    self.snap_application_date ||= Date.current
  end

  def set_applicant_attributes
    @applicant_attributes = agency_config&.applicant_attributes&.compact&.keys&.map(&:to_sym) || []

    @required_applicant_attributes = get_required_applicant_attributes
  end

  # Reset the applicant attributes to nil by removing any non-symbol keys i.e. { date_of_birth: [ :day, :month, :year ] }
  # and then setting the attributes to nil.
  def reset_applicant_attributes
    clear_attributes = applicant_attributes.reject { |key| !key.is_a?(Symbol) }.index_with(nil)
    update!(clear_attributes)
  end

  def is_applicant_attribute_required?(attribute)
    get_required_applicant_attributes
    .include?(attribute)
  end

  # Override this in a subclass based on the indexing data.
  #
  # This returns an array of names the agency gave us expecting to need
  # income verification.
  def agency_expected_names
    []
  end

  private

  def get_required_applicant_attributes
    agency_config&.applicant_attributes&.select { |key, attributes| attributes["required"] }&.keys&.map(&:to_sym) || []
  end

  def agency_config
    Rails.application.config.client_agencies[client_agency_id]
  end
end
