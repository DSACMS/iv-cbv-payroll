class RemoveLegacyFieldsFromJobTrainingActivities < ActiveRecord::Migration[7.2]
  def change
    remove_column :job_training_activities, :date, :date
    remove_column :job_training_activities, :hours, :integer
  end
end
