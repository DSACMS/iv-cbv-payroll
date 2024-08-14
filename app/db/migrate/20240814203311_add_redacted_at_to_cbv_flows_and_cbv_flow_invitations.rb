class AddRedactedAtToCbvFlowsAndCbvFlowInvitations < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_flows, :redacted_at, :datetime
    add_column :cbv_flow_invitations, :redacted_at, :datetime
  end
end
