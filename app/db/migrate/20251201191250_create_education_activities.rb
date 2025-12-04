class CreateEducationActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :education_activities do |t|
      t.belongs_to :identity, null: false, foreign_key: true
      t.text :additional_comments
      t.integer :credit_hours

      t.timestamps
    end
  end
end
