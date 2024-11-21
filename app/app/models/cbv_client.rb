class CbvClient < ApplicationRecord
  has_one :cbv_flow
  has_one :cbv_flow_invitation

  def self.create_from_invitation(cbv_flow_invitation)
    create(
      cbv_flow_invitation: cbv_flow_invitation,
      case_number: cbv_flow_invitation.case_number,
      first_name: cbv_flow_invitation.first_name,
      middle_name: cbv_flow_invitation.middle_name,
      last_name: cbv_flow_invitation.last_name,
      agency_id_number: cbv_flow_invitation.agency_id_number,
      client_id_number: cbv_flow_invitation.client_id_number,
      snap_application_date: cbv_flow_invitation.snap_application_date,
      beacon_id: cbv_flow_invitation.beacon_id
    )
  end
end
