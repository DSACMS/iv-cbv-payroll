class AddAdditionalCommentsToJobTrainingActivities < ActiveRecord::Migration[7.2]
  def change
    add_column :job_training_activities, :additional_comments, :text
  end
end
