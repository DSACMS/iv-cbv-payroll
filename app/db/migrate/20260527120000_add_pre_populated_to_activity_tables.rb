class AddPrePopulatedToActivityTables < ActiveRecord::Migration[8.1]
  class VolunteeringActivity < ApplicationRecord
    self.table_name = "volunteering_activities"
  end

  class EmploymentActivity < ApplicationRecord
    self.table_name = "employment_activities"
  end

  def up
    add_column :volunteering_activities, :pre_populated, :boolean, default: false, null: false
    add_column :employment_activities, :pre_populated, :boolean, default: false, null: false
    add_column :education_activities, :pre_populated, :boolean, default: false, null: false

    VolunteeringActivity.reset_column_information
    EmploymentActivity.reset_column_information

    # Replace the old skeleton marker with the new shared pre_populated flag.
    VolunteeringActivity.where(data_source: "state_provided").update_all(pre_populated: true, data_source: "self_attested")
    EmploymentActivity.where(data_source: "state_provided").update_all(pre_populated: true, data_source: "self_attested")
  end

  def down
    VolunteeringActivity.reset_column_information
    EmploymentActivity.reset_column_information

    VolunteeringActivity.where(pre_populated: true).update_all(data_source: "state_provided")
    EmploymentActivity.where(pre_populated: true).update_all(data_source: "state_provided")

    remove_column :volunteering_activities, :pre_populated
    remove_column :employment_activities, :pre_populated
    remove_column :education_activities, :pre_populated
  end
end
