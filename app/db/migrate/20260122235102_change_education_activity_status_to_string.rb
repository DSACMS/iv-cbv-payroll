class ChangeEducationActivityStatusToString < ActiveRecord::Migration[8.1]
  def change
    remove_column :education_activities, :status, :integer

    add_column :education_activities, :status, :string, default: "unknown"
  end
end
