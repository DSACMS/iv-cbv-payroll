class ActivityFlowInvitation < ApplicationRecord
  ACTIVITY_TYPES = {
    "volunteering" => VolunteeringActivity,
    "employment" => EmploymentActivity,
    "education" => EducationActivity,
    "job_training" => JobTrainingActivity
  }.freeze

  VALID_VERIFICATION_RANGES = %w[last_complete_month last_12_complete_months].freeze

  belongs_to :cbv_applicant, optional: true
  has_many :activity_flows
  has_one :household_member

  has_secure_token :auth_token, length: 10

  validates :verification_range, inclusion: {
    in: VALID_VERIFICATION_RANGES,
    message: :invalid_format,
    case_sensitive: true
  }, on: :v2

  def to_url(host: ENV.fetch("DOMAIN_NAME", "localhost"), **url_params)
    Rails.application.routes.url_helpers.activities_flow_start_url(token: auth_token, host: host, **url_params)
  end

  def expired?
    false
  end
end
