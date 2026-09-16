class RemovePrePopulatedFromMultipleTables < ActiveRecord::Migration[8.1]
  def change
    remove_column :activity_flow_invitations, :pre_populated_activities, :jsonb
    remove_column :volunteering_activities, :pre_populated, :boolean
    remove_column :job_training_activities, :pre_populated, :boolean
    remove_column :education_activities, :pre_populated, :boolean
    remove_column :employment_activities, :pre_populated, :boolean
  end
end
