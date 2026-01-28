class RemoveEnrollmentStatusAndSchoolFromEducationActivity < ActiveRecord::Migration[8.1]
  def change
    remove_column :education_activities, :enrollment_status, :string
    remove_column :education_activities, :school_name, :string
    remove_column :education_activities, :school_address, :string
  end
end
