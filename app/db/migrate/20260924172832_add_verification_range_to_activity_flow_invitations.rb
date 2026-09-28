class AddVerificationRangeToActivityFlowInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flow_invitations, :verification_range, :string
  end
end
