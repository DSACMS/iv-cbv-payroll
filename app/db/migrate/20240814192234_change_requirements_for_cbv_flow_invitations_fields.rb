class ChangeRequirementsForCbvFlowInvitationsFields < ActiveRecord::Migration[7.1]
  def change
    change_column_null :cbv_flow_invitations, :middle_name, true
    change_column_null :cbv_flow_invitations, :snap_application_date, false, Time.zone.now
  end
end
