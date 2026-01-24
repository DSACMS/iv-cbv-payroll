class ActivityFlowInvitation < ApplicationRecord
  belongs_to :cbv_applicant, optional: true
  has_many :activity_flows

  has_secure_token :auth_token, length: 10

  def to_url(host: ENV.fetch("DOMAIN_NAME", "localhost"), reporting_window: nil)
    Rails.application.routes.url_helpers.activities_flow_start_url(
      token: auth_token,
      host: host,
      reporting_window: reporting_window
    )
  end

  def expired?
    false
  end
end
