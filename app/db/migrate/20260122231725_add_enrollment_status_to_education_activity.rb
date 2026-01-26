class AddEnrollmentStatusToEducationActivity < ActiveRecord::Migration[8.1]
  def change
    change_table :education_activities do |t|
      t.string :enrollment_status, default: "unknown"
    end
  end
end
