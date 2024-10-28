class AddCbvInvitationRefToCbvFlows < ActiveRecord::Migration[7.0]
  def change
    add_reference :cbv_flows, :cbv_flow_invitation, foreign_key: true
  end
end
