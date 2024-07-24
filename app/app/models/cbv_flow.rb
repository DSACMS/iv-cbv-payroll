class CbvFlow < ApplicationRecord
  belongs_to :cbv_flow_invitation, optional: true
  validates :site_id, inclusion: Rails.application.config.sites.site_ids

  def self.create_from_invitation(cbv_flow_invitation)
    create(
      cbv_flow_invitation: cbv_flow_invitation,
      case_number: cbv_flow_invitation.case_number,
      site_id: cbv_flow_invitation.site_id
    )
  end
end
