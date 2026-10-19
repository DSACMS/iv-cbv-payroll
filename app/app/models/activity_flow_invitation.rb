class ActivityFlowInvitation < ApplicationRecord
  INVITATION_VALIDITY_TIME_ZONE = "America/New_York"

  ACTIVITY_TYPES = {
    "volunteering" => VolunteeringActivity,
    "employment" => EmploymentActivity,
    "education" => EducationActivity,
    "job_training" => JobTrainingActivity
  }.freeze

  belongs_to :cbv_applicant, optional: true
  has_many :activity_flows
  has_one :household_member

  has_secure_token :auth_token, length: 10

  before_create :set_expires_at, if: :new_record?

  validates :verification_range, inclusion: {
    in: Flow::VALID_VERIFICATION_RANGES,
    message: :invalid_format,
    case_sensitive: true
  }, on: :v2

  def to_url(host: ENV.fetch("DOMAIN_NAME", "localhost"), **url_params)
    Rails.application.routes.url_helpers.activities_flow_start_url(token: auth_token, host: host, **url_params)
  end

  def expired?
    Time.current.after?(expires_at)
  end

  private

  def set_expires_at
    self.expires_at ||= calculate_expires_at
  end

  # Invitations are valid until 11:59pm Eastern Time on the (e.g.) 14th day
  # after sending the invitation.
  def calculate_expires_at
    end_of_day_sent = created_at.in_time_zone(INVITATION_VALIDITY_TIME_ZONE).end_of_day
    days_valid_for = Rails.application.config.client_agencies[client_agency_id].invitation_valid_days

    end_of_day_sent + days_valid_for.days
  end
end
