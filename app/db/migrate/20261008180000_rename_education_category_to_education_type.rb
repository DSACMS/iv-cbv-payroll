class RenameEducationCategoryToEducationType < ActiveRecord::Migration[8.1]
  def change
    rename_column :education_activities, :education_category, :education_type
  end
end
