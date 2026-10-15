class AddEducationTypeToEducationActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :education_activities, :education_type, :string
  end
end
