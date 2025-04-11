class AddIncomeChangesToCbvApplicant < ActiveRecord::Migration[7.1]
  def change
    change_table :cbv_applicants do |t|
      t.jsonb :income_changes
    end
  end
end
