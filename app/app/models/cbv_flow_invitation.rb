class CbvFlowInvitation < ApplicationRecord
  # The incoming snap_application_date is a string in the format "MM/DD/YYYY".
  # We need to convert it to a Date object before we can use it.
  before_validation :parse_snap_application_date

  has_secure_token :auth_token, length: 36
  validates :site_id, inclusion: Rails.application.config.sites.site_ids
  validates :case_number, presence: true, if: :nyc_site?
  validates :agency_id_number, presence: true, if: :ma_site?
  validates :beacon_id, presence: true, if: :ma_site?
  validates :email_address, presence: true
  validates :snap_application_date, presence: true

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

  has_one :cbv_flow
  scope :unstarted, -> { left_outer_joins(:cbv_flow).where(cbv_flows: { id: nil }) }

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

    begin
      new_date_format = Date.strptime(raw_snap_application_date.to_s, "%m/%d/%Y")
      self.snap_application_date = new_date_format
    rescue Date::Error
      self.errors.add(:snap_application_date, "is not a valid date")
    end
  end
end
