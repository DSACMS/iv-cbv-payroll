class AddSchoolInfoToEducationActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :education_activities, :school_name, :string
    add_column :education_activities, :street_address, :string
    add_column :education_activities, :street_address_line_2, :string
    add_column :education_activities, :city, :string
    add_column :education_activities, :state, :string
    add_column :education_activities, :zip_code, :string
    add_column :education_activities, :contact_name, :string
    add_column :education_activities, :contact_email, :string
    add_column :education_activities, :contact_phone_number, :string
  end
end
