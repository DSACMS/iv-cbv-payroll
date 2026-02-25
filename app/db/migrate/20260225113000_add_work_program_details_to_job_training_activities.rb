class AddWorkProgramDetailsToJobTrainingActivities < ActiveRecord::Migration[7.2]
  def change
    add_column :job_training_activities, :organization_name, :string
    add_column :job_training_activities, :street_address, :string
    add_column :job_training_activities, :street_address_line_2, :string
    add_column :job_training_activities, :city, :string
    add_column :job_training_activities, :state, :string
    add_column :job_training_activities, :zip_code, :string
    add_column :job_training_activities, :contact_name, :string
    add_column :job_training_activities, :contact_email, :string
    add_column :job_training_activities, :contact_phone_number, :string
  end
end
