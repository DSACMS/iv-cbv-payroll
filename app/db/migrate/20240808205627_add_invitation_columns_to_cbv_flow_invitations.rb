class AddInvitationColumnsToCbvFlowInvitations < ActiveRecord::Migration[7.0]
  def change
    add_column :cbv_flow_invitations, :first_name, :string
    add_column :cbv_flow_invitations, :middle_name, :string
    add_column :cbv_flow_invitations, :last_name, :string
    add_column :cbv_flow_invitations, :agency_id_number, :string
    add_column :cbv_flow_invitations, :client_id_number, :string
    add_column :cbv_flow_invitations, :snap_application_date, :date
    add_column :cbv_flow_invitations, :beacon_id, :string
  end
end