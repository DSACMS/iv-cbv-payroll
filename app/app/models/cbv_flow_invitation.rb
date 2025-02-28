class CbvFlowInvitation < ApplicationRecord
  # We're opting not to use URI::MailTo::EMAIL_REGEXP
  # https://html.spec.whatwg.org/multipage/input.html#valid-e-mail-address
  #
  # EXCERPT: This requirement is a willful violation of RFC 5322, which defines a syntax for email addresses
  # that is simultaneously too strict (before the "@" character), too vague (after the "@" character),
  # and too lax (allowing comments, whitespace characters, and quoted strings in manners unfamiliar to most users)
  # to be of practical use here.
  EMAIL_REGEX = /\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z\d\-]+\z/i

  INVITATION_VALIDITY_TIME_ZONE = "America/New_York"

  VALID_LOCALES = Rails.application.config.i18n.available_locales.map(&:to_s).freeze

  belongs_to :user
  belongs_to :cbv_applicant, optional: true
  has_many :cbv_flows

  has_secure_token :auth_token, length: 36

  accepts_nested_attributes_for :cbv_applicant

  before_validation :normalize_language

  validates :client_agency_id, inclusion: Rails.application.config.client_agencies.client_agency_ids
  validates :email_address, format: { with: EMAIL_REGEX, message: :invalid_format }
  validates_associated :cbv_applicant
  validates :language, inclusion: {
    in: VALID_LOCALES,
    message: :invalid_format,
    case_sensitive: false
  }

  include Redactable
  has_redactable_fields(
    email_address: :email,
    auth_token: :string
  )

  scope :unstarted, -> { left_outer_joins(:cbv_flows).where(cbv_flows: { id: nil }) }

  # Invitations are valid until 11:59pm Eastern Time on the (e.g.) 14th day
  # after sending the invitation.
  def expires_at
    end_of_day_sent = created_at.in_time_zone(INVITATION_VALIDITY_TIME_ZONE).end_of_day
    days_valid_for = Rails.application.config.client_agencies[client_agency_id].invitation_valid_days

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

  def normalize_language
    self.language = language.to_s.downcase if language.present?
  end
end
