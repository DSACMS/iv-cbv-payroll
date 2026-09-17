class RemovePrePropulatedActivitiesFromActivityInvitationFlow < ActiveRecord::Migration[8.1]
  def change
    remove_column :activity_flow_invitations, :pre_populated_activities, :jsonb
  end
end
