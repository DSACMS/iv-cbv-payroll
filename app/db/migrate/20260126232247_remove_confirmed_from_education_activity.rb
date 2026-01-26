class RemoveConfirmedFromEducationActivity < ActiveRecord::Migration[8.1]
  def change
    remove_column :education_activities, :confirmed, :boolean
  end
end
