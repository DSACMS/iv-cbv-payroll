class CreateVolunteeringActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :volunteering_activities do |t|
      t.references :activity_flow, null: false, foreign_key: true
      t.string :organization_name
      t.date :date
      t.integer :hours

      t.timestamps
    end
  end
end
