class CbvFlowInvitation < ApplicationRecord
  has_secure_token :auth_token, length: 36
  validates :site_id, inclusion: Rails.application.config.sites.site_ids

  has_one :cbv_flow

  def to_url
    Rails.application.routes.url_helpers.cbv_flow_entry_url(token: auth_token)
  end
end
