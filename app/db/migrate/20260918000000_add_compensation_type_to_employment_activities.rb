class AddCompensationTypeToEmploymentActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :employment_activities, :compensation_type, :string, default: "paid", null: false
  end
end
