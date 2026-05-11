class AddPrePopulatedActivitiesToActivityFlowInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flow_invitations, :pre_populated_activities, :jsonb, default: [], null: false
  end
end
