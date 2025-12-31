class AddDateToJobTrainingActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :job_training_activities, :date, :date
  end
end
