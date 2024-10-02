class AddLanguageToCbvFlowInvitations < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_flow_invitations, :language, :string
  end
end
