class AddEducationActivityToEnrollment < ActiveRecord::Migration[7.2]
  def change
    add_reference :enrollments, :education_activity, foreign_key: true
  end
end
