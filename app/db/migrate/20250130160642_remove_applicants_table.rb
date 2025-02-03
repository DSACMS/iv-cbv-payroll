class RemoveApplicantsTable < ActiveRecord::Migration[7.1]
  def change
    drop_table :applicants
  end
end
