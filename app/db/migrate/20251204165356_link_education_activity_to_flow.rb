class LinkEducationActivityToFlow < ActiveRecord::Migration[7.2]
  def change
    change_table :education_activities do |t|
      t.belongs_to :activity_flow, null: false, foreign_key: true
      t.string :status
      t.string :school_name
      t.string :school_address
      t.boolean :confirmed, default: false

      t.remove_references :identity
    end
  end
end
