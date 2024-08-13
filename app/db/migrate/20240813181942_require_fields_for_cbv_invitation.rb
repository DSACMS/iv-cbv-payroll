class RequireFieldsForCbvInvitation < ActiveRecord::Migration[7.1]
  def change
    change_column_null :cbv_flow_invitations, :first_name, false, "Unknown"
    change_column_null :cbv_flow_invitations, :middle_name, false, "Unknown"
    change_column_null :cbv_flow_invitations, :last_name, false, "Unknown"
    change_column_null :cbv_flow_invitations, :agency_id_number, false, "Unknown"
    change_column_null :cbv_flow_invitations, :client_id_number, false, "Unknown"
    change_column_null :cbv_flow_invitations, :snap_application_date, false, Time.zone.now
  end
end
