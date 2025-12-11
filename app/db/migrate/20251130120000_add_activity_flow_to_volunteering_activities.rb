class AddActivityFlowToVolunteeringActivities < ActiveRecord::Migration[7.2]
  def change
    VolunteeringActivity.delete_all
    add_reference :volunteering_activities, :activity_flow, null: false, foreign_key: true
  end
end
