class ActivityFlowInvitation < ApplicationRecord
  # Remove after pre_populated_activities column is removed from the database
  self.ignored_columns += %w[pre_populated_activities]
  belongs_to :cbv_applicant, optional: true
  has_many :activity_flows
  has_one :household_member

  has_secure_token :auth_token, length: 10

  def to_url(host: ENV.fetch("DOMAIN_NAME", "localhost"), **url_params)
    Rails.application.routes.url_helpers.activities_flow_start_url(token: auth_token, host: host, **url_params)
  end

  def expired?
    false
  end
end
