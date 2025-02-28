class RemoveIndexingFieldsFromCbvFlowInvitation < ActiveRecord::Migration[7.1]
  def change
    remove_column :cbv_flow_invitations, :case_number
    remove_column :cbv_flow_invitations, :first_name
    remove_column :cbv_flow_invitations, :middle_name
    remove_column :cbv_flow_invitations, :last_name
    remove_column :cbv_flow_invitations, :agency_id_number
    remove_column :cbv_flow_invitations, :client_id_number
    remove_column :cbv_flow_invitations, :snap_application_date
    remove_column :cbv_flow_invitations, :beacon_id

    remove_column :cbv_flows, :case_number
  end
end
