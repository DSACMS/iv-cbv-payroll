class AddExpiresAtToActivityFlowInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flow_invitations, :expires_at, :datetime
  end
end
