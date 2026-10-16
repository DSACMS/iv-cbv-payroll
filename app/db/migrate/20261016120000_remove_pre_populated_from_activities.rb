class RemovePrePopulatedFromActivities < ActiveRecord::Migration[8.1]
  def change
    remove_column :volunteering_activities, :pre_populated, :boolean, default: false, null: false
    remove_column :employment_activities, :pre_populated, :boolean, default: false, null: false
    remove_column :education_activities, :pre_populated, :boolean, default: false, null: false
    remove_column :job_training_activities, :pre_populated, :boolean, default: false, null: false
  end
end
