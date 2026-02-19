class AddAdditionalCommentsToVolunteeringActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :volunteering_activities, :additional_comments, :text
  end
end
