class CreateJoinTableEducationActivitiesEnrollments < ActiveRecord::Migration[7.2]
  def change
    create_join_table :education_activities, :enrollments
  end
end
