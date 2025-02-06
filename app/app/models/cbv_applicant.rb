class CbvApplicant < ApplicationRecord
  # Massachusetts: 7 digits
  MA_AGENCY_ID_REGEX = /\A\d{7}\z/

  # Massachusetts: 6 alphanumeric characters
  MA_BEACON_ID_REGEX = /\A[a-zA-Z0-9]{6}\z/

  # New York City: 11 digits followed by 1 uppercase letter
  NYC_CASE_NUMBER_REGEX = /\A\d{11}[A-Z]\z/

  # New York City: 2 uppercase letters, followed by 5 digits, followed by 1 uppercase letter
  NYC_CLIENT_ID_REGEX = /\A[A-Z]{2}\d{5}[A-Z]\z/

  PAYSTUB_REPORT_RANGE = 90.days

  has_many :cbv_flows
  has_many :cbv_flow_invitations

  before_validation :parse_snap_application_date
  before_validation :format_case_number

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :site_id, presence: true

  # MA specific validations
  with_options(if: :ma_site?) do
    validates :agency_id_number, format: { with: MA_AGENCY_ID_REGEX, message: :invalid_format }
    validates :beacon_id, format: { with: MA_BEACON_ID_REGEX, message: :invalid_format }
    validate :ma_snap_application_date_not_more_than_1_year_ago
    validate :ma_snap_application_date_not_in_future
  end

  # NYC specific validations
  with_options(if: :nyc_site?) do
    validates :case_number, format: { with: NYC_CASE_NUMBER_REGEX, message: :invalid_format }
    validates :client_id_number, format: { with: NYC_CLIENT_ID_REGEX, message: :invalid_format }
    validate :nyc_snap_application_date_not_more_than_30_days_ago
    validate :nyc_snap_application_date_not_in_future
  end

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

  def self.create_from_invitation(cbv_flow_invitation)
    client = create!(
      site_id: cbv_flow_invitation.site_id,
      case_number: cbv_flow_invitation.case_number,
      first_name: cbv_flow_invitation.first_name,
      middle_name: cbv_flow_invitation.middle_name,
      last_name: cbv_flow_invitation.last_name,
      agency_id_number: cbv_flow_invitation.agency_id_number,
      client_id_number: cbv_flow_invitation.client_id_number,
      snap_application_date: cbv_flow_invitation.snap_application_date,
      beacon_id: cbv_flow_invitation.beacon_id
    )
    cbv_flow_invitation.update_column(:cbv_applicant_id, client.id)
    client
  end

  def ma_site?
    site_id == "ma"
  end

  def nyc_site?
    site_id == "nyc"
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
      rescue Date::Error => e
        case site_id
        when "ma"
          error = :ma_invalid_date
        when "nyc"
          error = :nyc_invalid_date
        else
          error = :default_invalid_date
        end
        errors.add(:snap_application_date, error)
      end
    end
  end

  def ma_snap_application_date_not_in_future
    if snap_application_date.present? && snap_application_date > Date.current
      errors.add(:snap_application_date, :ma_invalid_date)
    end
  end

  def ma_snap_application_date_not_more_than_1_year_ago
    if snap_application_date.present? && snap_application_date < 1.year.ago.to_date
      errors.add(:snap_application_date, :ma_invalid_date)
    end
  end

  def nyc_snap_application_date_not_in_future
    if snap_application_date.present? && snap_application_date > Date.current
      errors.add(:snap_application_date, :nyc_invalid_date)
    end
  end

  def nyc_snap_application_date_not_more_than_30_days_ago
    if snap_application_date.present? && snap_application_date < 30.day.ago.to_date
      errors.add(:snap_application_date, :nyc_invalid_date)
    end
  end

  def format_case_number
    return if case_number.blank?
    case_number.upcase!
    if case_number.length == 9
      self.case_number = "000#{case_number}"
    end
  end

  def paystubs_query_begins_at
    PAYSTUB_REPORT_RANGE.before(snap_application_date)
  end
end
