class CreateJobTrainingActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :job_training_activities do |t|
      t.string :program_name
      t.string :organization_address
      t.integer :hours

      t.timestamps
    end
  end
end
