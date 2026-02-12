class ActivityFlowInvitation < ApplicationRecord
  belongs_to :cbv_applicant, optional: true
  has_many :activity_flows

  has_secure_token :auth_token, length: 10

  def to_url(host: ENV.fetch("DOMAIN_NAME", "localhost"), protocol: nil, reporting_window: nil)
    url_params = { token: auth_token, host: host, reporting_window: reporting_window }
    url_params[:protocol] = protocol if protocol
    Rails.application.routes.url_helpers.activities_flow_start_url(**url_params)
  end

  def expired?
    false
  end
end
