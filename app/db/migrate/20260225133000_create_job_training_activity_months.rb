class CreateJobTrainingActivityMonths < ActiveRecord::Migration[7.2]
  def change
    create_table :job_training_activity_months do |t|
      t.references :job_training_activity, null: false, foreign_key: true
      t.date :month, null: false
      t.integer :hours, default: 0, null: false
      t.timestamps
    end
  end
end
