class AddEmploymentFocusedToActivityFlowInvitation < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flow_invitations, :employment_focused, :boolean, null: false, default: false
  end
end
