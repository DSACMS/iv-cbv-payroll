class AddVerificationRangeToCbvFlowInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :cbv_flow_invitations, :verification_range, :string
  end
end
