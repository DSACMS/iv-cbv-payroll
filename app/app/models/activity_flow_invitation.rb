class ActivityFlowInvitation < ApplicationRecord
  belongs_to :cbv_applicant, optional: true
  has_many :activity_flows

  has_secure_token :auth_token, length: 10

  def to_url(host: ENV.fetch("DOMAIN_NAME", "localhost"), **url_params)
    Rails.application.routes.url_helpers.activities_flow_start_url(**url_params)
  end
  end

  def expired?
    false
  end
end
