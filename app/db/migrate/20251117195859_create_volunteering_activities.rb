class CreateVolunteeringActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :volunteering_activities do |t|
      t.string :organization_name
      t.date :date
      t.integer :hours

      t.timestamps
    end
  end
end
