class CreateEmploymentActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :employment_activities do |t|
      t.string :employer_name
      t.string :street_address
      t.string :street_address_line_2
      t.string :city
      t.string :state
      t.string :zip_code
      t.boolean :is_self_employed, default: false
      t.string :contact_name
      t.string :contact_email
      t.string :contact_phone_number
      t.references :activity_flow, null: false, foreign_key: true
      t.string :data_source, default: "self_attested", null: false

      t.timestamps
    end
  end
end
