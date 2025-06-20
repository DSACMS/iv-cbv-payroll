class AddExpiresAtToCbvFlowInvitations < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_flow_invitations, :expires_at, :timestamp
  end
end
