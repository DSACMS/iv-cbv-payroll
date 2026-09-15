class AddSelectedMonthsToEmploymentActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :employment_activities, :selected_months, :date, array: true, default: [], null: false
  end
end
