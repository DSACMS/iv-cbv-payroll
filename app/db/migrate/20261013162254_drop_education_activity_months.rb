class DropEducationActivityMonths < ActiveRecord::Migration[8.1]
  def change
    drop_table :education_activity_months do |t|
      t.references :education_activity, null: false, foreign_key: true
      t.date :month, null: false
      t.decimal :hours, precision: 10, scale: 2, default: 0, null: false
      t.timestamps
    end
  end
end
