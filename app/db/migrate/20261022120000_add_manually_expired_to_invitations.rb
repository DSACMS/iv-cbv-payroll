class AddManuallyExpiredToInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :cbv_flow_invitations, :manually_expired, :boolean, default: false, null: false
    add_column :activity_flow_invitations, :manually_expired, :boolean, default: false, null: false
  end
end
