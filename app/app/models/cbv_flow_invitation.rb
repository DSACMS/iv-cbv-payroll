class CbvFlowInvitation < ApplicationRecord
  EMAIL_REGEX = URI::MailTo::EMAIL_REGEXP

  # Massachusetts: 7 digits
  MA_AGENCY_ID_REGEX = /\A\d{7}\z/

  # Massachusetts: 6 alphanumeric characters
  MA_BEACON_ID_REGEX = /\A[a-zA-Z0-9]{6}\z/

  # New York City: 11 digits followed by 1 uppercase letter
  NYC_CASE_NUMBER_REGEX = /\A\d{11}[A-Z]\z/

  # New York City: 2 uppercase letters, followed by 5 digits, followed by 1 uppercase letter
  NYC_CLIENT_ID_REGEX = /\A[A-Z]{2}\d{5}[A-Z]\z/

  belongs_to :user
  has_many :cbv_flows

  has_secure_token :auth_token, length: 36

  before_validation :parse_snap_application_date
  before_validation :format_case_number, if: :nyc_site?

  validates :site_id, inclusion: Rails.application.config.sites.site_ids
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email_address, format: { with: EMAIL_REGEX, message: :invalid_format }
  validates :snap_application_date, presence: true

  # MA specific validations
  validates :agency_id_number, format: { with: MA_AGENCY_ID_REGEX, message: :invalid_format }, if: :ma_site?
  validates :beacon_id, format: { with: MA_BEACON_ID_REGEX, message: :invalid_format }, if: :ma_site?
  validate :ma_snap_application_date_not_more_than_1_year_ago, if: :ma_site?
  validate :ma_snap_application_date_not_in_future


  # NYC specific validations
  validates :case_number, presence: true, format: { with: NYC_CASE_NUMBER_REGEX, message: :invalid_format }, if: :nyc_site?
  validates :client_id_number, format: { with: NYC_CLIENT_ID_REGEX, message: :invalid_format }, if: -> { nyc_site? && client_id_number.present? }
  validate :nyc_snap_application_date_not_more_than_30_days_ago, if: :nyc_site?
  validate :nyc_snap_application_date_not_in_future, if: :nyc_site?

  include Redactable
  has_redactable_fields(
    first_name: :string,
    middle_name: :string,
    last_name: :string,
    client_id_number: :string,
    case_number: :string,
    agency_id_number: :string,
    beacon_id: :string,
    email_address: :email,
    snap_application_date: :date,
    auth_token: :string
  )

  INVITATION_VALIDITY_TIME_ZONE = "America/New_York"
  PAYSTUB_REPORT_RANGE = 90.days

  scope :unstarted, -> { left_outer_joins(:cbv_flows).where(cbv_flows: { id: nil }) }

  # Invitations are valid until 11:59pm Eastern Time on the (e.g.) 14th day
  # after sending the invitation.
  def expires_at
    end_of_day_sent = created_at.in_time_zone(INVITATION_VALIDITY_TIME_ZONE).end_of_day
    days_valid_for = Rails.application.config.sites[site_id].invitation_valid_days

    end_of_day_sent + days_valid_for.days
  end

  def expired?
    Time.now.after?(expires_at) || redacted_at?
  end

  def complete?
    cbv_flows.any?(&:complete?)
  end

  def to_url
    Rails.application.routes.url_helpers.cbv_flow_entry_url(token: auth_token)
  end

  def paystubs_query_begins_at
    PAYSTUB_REPORT_RANGE.before(snap_application_date)
  end

  private

  def nyc_site?
    site_id == "nyc"
  end

  def ma_site?
    site_id == "ma"
  end

  def parse_snap_application_date
    raw_snap_application_date = @attributes["snap_application_date"]&.value_before_type_cast
    return if raw_snap_application_date.is_a?(Date)

    if raw_snap_application_date.is_a?(ActiveSupport::TimeWithZone) || raw_snap_application_date.is_a?(Time)
      self.snap_application_date = raw_snap_application_date.to_date
    else
      begin
        new_date_format = Date.strptime(raw_snap_application_date.to_s, "%m/%d/%Y")
        self.snap_application_date = new_date_format
      rescue Date::Error => e
        errors.add(:snap_application_date, :invalid_date)
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
end
