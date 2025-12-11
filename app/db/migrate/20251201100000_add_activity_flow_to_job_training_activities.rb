class AddActivityFlowToJobTrainingActivities < ActiveRecord::Migration[7.2]
  def change
    JobTrainingActivity.delete_all
    add_reference :job_training_activities, :activity_flow, null: false, foreign_key: true
  end
end
