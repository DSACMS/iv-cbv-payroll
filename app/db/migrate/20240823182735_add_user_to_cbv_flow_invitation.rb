class AddUserToCbvFlowInvitation < ActiveRecord::Migration[7.1]
  def change
    add_reference :cbv_flow_invitations, :user, null: true, foreign_key: true
  end
end
