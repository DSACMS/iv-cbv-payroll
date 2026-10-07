class AddContactTitleToEducationActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :education_activities, :contact_title, :string
  end
end
