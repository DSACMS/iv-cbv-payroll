class AddUniqueIndexToAuthTokenOnCbvFlowInvitations < ActiveRecord::Migration[7.2]
  def change
    add_index :cbv_flow_invitations, :auth_token, unique: true
  end
end
