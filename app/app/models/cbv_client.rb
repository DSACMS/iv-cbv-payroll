class CbvClient < ApplicationRecord
  has_one :cbv_flow
  has_one :cbv_flow_invitation

  # Include the Redactable concern
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
    snap_application_date: :date
  )

  # We're opting not to use URI::MailTo::EMAIL_REGEXP
  # https://html.spec.whatwg.org/multipage/input.html#valid-e-mail-address
  #
  # EXCERPT: This requirement is a willful violation of RFC 5322, which defines a syntax for email addresses
  # that is simultaneously too strict (before the "@" character), too vague (after the "@" character),
  # and too lax (allowing comments, whitespace characters, and quoted strings in manners unfamiliar to most users)
  # to be of practical use here.
  EMAIL_REGEX = /\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z\d\-]+\z/i

  # Massachusetts: 7 digits
  MA_AGENCY_ID_REGEX = /\A\d{7}\z/

  # Massachusetts: 6 alphanumeric characters
  MA_BEACON_ID_REGEX = /\A[a-zA-Z0-9]{6}\z/

  # New York City: 11 digits followed by 1 uppercase letter
  NYC_CASE_NUMBER_REGEX = /\A\d{11}[A-Z]\z/

  # New York City: 2 uppercase letters, followed by 5 digits, followed by 1 uppercase letter
  NYC_CLIENT_ID_REGEX = /\A[A-Z]{2}\d{5}[A-Z]\z/

  ISO_8601_DATE_REGEX = /\A\d{4}-\d{2}-\d{2}\z/

  # PII Validations and Callbacks
  before_validation :parse_snap_application_date
  before_validation :format_case_number, if: :nyc_site?
  before_validation :normalize_language

  validates :site_id, inclusion: Rails.application.config.sites.site_ids
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email_address, format: { with: EMAIL_REGEX, message: :invalid_format }
  validates :language, inclusion: {
    in: VALID_LOCALES,
    message: :invalid_format,
    case_sensitive: false
  }

  # MA specific validations
  validates :agency_id_number, format: { with: MA_AGENCY_ID_REGEX, message: :invalid_format }, if: :ma_site?
  validates :beacon_id, format: { with: MA_BEACON_ID_REGEX, message: :invalid_format }, if: :ma_site?
  validate :ma_snap_application_date_not_more_than_1_year_ago, if: :ma_site?
  validate :ma_snap_application_date_not_in_future, if: :ma_site?

  # NYC specific validations
  validates :case_number, format: { with: NYC_CASE_NUMBER_REGEX, message: :invalid_format }, if: :nyc_site?
  validates :client_id_number, format: { with: NYC_CLIENT_ID_REGEX, message: :invalid_format }, if: :nyc_site?
  validate :nyc_snap_application_date_not_more_than_30_days_ago, if: :nyc_site?
  validate :nyc_snap_application_date_not_in_future, if: :nyc_site?

  def self.create_from_invitation(cbv_flow_invitation)
    client = create!(
      case_number: cbv_flow_invitation.case_number,
      first_name: cbv_flow_invitation.first_name,
      middle_name: cbv_flow_invitation.middle_name,
      last_name: cbv_flow_invitation.last_name,
      agency_id_number: cbv_flow_invitation.agency_id_number,
      client_id_number: cbv_flow_invitation.client_id_number,
      snap_application_date: cbv_flow_invitation.snap_application_date,
      beacon_id: cbv_flow_invitation.beacon_id
    )
    cbv_flow_invitation.update_column(:cbv_client_id, client.id)
    client
  end

  private

  def nyc_site?
    site_id == "nyc"
  end

  def ma_site?
    site_id == "ma"
  end

  def parse_snap_application_date
    raw_snap_application_date = self.snap_application_date_before_type_cast
    return if raw_snap_application_date.is_a?(Date)

    if raw_snap_application_date.is_a?(ActiveSupport::TimeWithZone) || raw_snap_application_date.is_a?(Time)
      self.snap_application_date = raw_snap_application_date.to_date
    elsif raw_snap_application_date.is_a?(String) && raw_snap_application_date.match?(ISO_8601_DATE_REGEX)
      self.snap_application_date = Date.parse(raw_snap_application_date)
    else
      begin
        new_date_format = Date.strptime(raw_snap_application_date.to_s, "%m/%d/%Y")
        self.snap_application_date = new_date_format
      rescue Date::Error
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
    if snap_application_date.present? && snap_application_date < 30.days.ago.to_date
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

  def normalize_language
    self.language = language.to_s.downcase if language.present?
  end
end
