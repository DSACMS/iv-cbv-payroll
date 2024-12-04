class CbvFlowInvitation < ApplicationRecord
  belongs_to :user
  belongs_to :cbv_client, optional: true
  has_many :cbv_flows

  has_secure_token :auth_token, length: 36

  # Invitation validity time zone
  INVITATION_VALIDITY_TIME_ZONE = "America/New_York"

  # Paystub report range
  PAYSTUB_REPORT_RANGE = 90.days

  # Valid locales
  VALID_LOCALES = Rails.application.config.i18n.available_locales.map(&:to_s).freeze

  # Updated validations
  validates :site_id, inclusion: Rails.application.config.sites.site_ids
  validates :language, inclusion: {
    in: VALID_LOCALES,
    message: :invalid_format,
    case_sensitive: false
  }

  scope :unstarted, -> { left_outer_joins(:cbv_flows).where(cbv_flows: { id: nil }) }

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
    Rails.application.routes.url_helpers.cbv_flow_entry_url(token: auth_token, locale: language)
  end

  def paystubs_query_begins_at
    PAYSTUB_REPORT_RANGE.before(snap_application_date)
  end

  private

  def normalize_language
    self.language = language.to_s.downcase if language.present?
  end
end
