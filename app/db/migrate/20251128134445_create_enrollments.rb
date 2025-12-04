class CreateEnrollments < ActiveRecord::Migration[7.2]
  def change
    create_table :enrollments do |t|
      t.belongs_to :school, null: false, foreign_key: true
      t.date :semester_start
      t.string :status

      t.timestamps
    end
  end
end
