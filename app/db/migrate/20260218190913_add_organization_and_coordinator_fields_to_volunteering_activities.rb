class AddOrganizationAndCoordinatorFieldsToVolunteeringActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :volunteering_activities, :street_address, :string
    add_column :volunteering_activities, :street_address_line_2, :string
    add_column :volunteering_activities, :city, :string
    add_column :volunteering_activities, :state, :string
    add_column :volunteering_activities, :zip_code, :string
    add_column :volunteering_activities, :coordinator_name, :string
    add_column :volunteering_activities, :coordinator_email, :string
    add_column :volunteering_activities, :coordinator_phone_number, :string
  end
end
