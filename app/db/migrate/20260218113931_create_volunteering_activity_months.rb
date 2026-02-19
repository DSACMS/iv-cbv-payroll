class CreateVolunteeringActivityMonths < ActiveRecord::Migration[7.2]
  def change
    create_table :volunteering_activity_months do |t|
      t.references :volunteering_activity, null: false, foreign_key: true
      t.date :month, null: false
      t.integer :hours, default: 0, null: false
      t.timestamps
    end
  end
end
