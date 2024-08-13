class CbvFlowInvitation < ApplicationRecord
  has_secure_token :auth_token, length: 36
  validates :site_id, inclusion: Rails.application.config.sites.site_ids
  validates :client_id_number, presence: true, if: :nyc_site?
  validates :case_number, presence: true, if: :nyc_site?
  validates :agency_id_number, presence: true, if: :ma_site?
  validates :beacon_id, presence: true, if: :ma_site?
  validates :email_address, presence: true

  include Redactable
  has_redactable_fields(
    case_number: :string,
    email_address: :email,
    auth_token: :string
  )

  INVITATION_VALIDITY_TIME_ZONE = "America/New_York"

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
    Time.now.after?(expires_at)
  end

  def to_url
    Rails.application.routes.url_helpers.cbv_flow_entry_url(token: auth_token)
  end

  private

  def nyc_site?
    site_id == "nyc"
  end

  def ma_site?
    site_id == "ma"
  end
end
