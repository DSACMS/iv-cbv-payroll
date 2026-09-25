class AddEmploymentFocusedToActivityFlows < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flows, :employment_focused, :boolean, null: false, default: false
  end
end
