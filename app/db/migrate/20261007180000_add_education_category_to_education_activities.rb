class AddEducationCategoryToEducationActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :education_activities, :education_category, :string
  end
end
