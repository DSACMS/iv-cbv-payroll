class RequireFieldsForCbvInvitation < ActiveRecord::Migration[7.1]
  def change
    change_column_null :cbv_flow_invitations, :agency_id_number, true, nil
    change_column_null :cbv_flow_invitations, :first_name, false, "Unknown"
    change_column_null :cbv_flow_invitations, :middle_name, false, "Unknown"
    change_column_null :cbv_flow_invitations, :last_name, false, "Unknown"
  end
end
