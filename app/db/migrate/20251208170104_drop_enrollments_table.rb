class DropEnrollmentsTable < ActiveRecord::Migration[7.2]
  def change
    drop_table(:enrollments)
  end
end
