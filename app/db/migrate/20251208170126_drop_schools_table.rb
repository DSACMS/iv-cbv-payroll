class DropSchoolsTable < ActiveRecord::Migration[7.2]
  def change
    drop_table(:schools)
  end
end
