class CbvFlow < ApplicationRecord
  belongs_to :cbv_flow_invitation, optional: true

  def self.create_from_invitation(cbv_flow_invitation)
    create(
      cbv_flow_invitation: cbv_flow_invitation,
      case_number: cbv_flow_invitation.case_number
    )
  end
end
