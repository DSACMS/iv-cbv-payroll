class AddAdditionalCommentsToEmploymentActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :employment_activities, :additional_comments, :text
  end
end
