class AddCompletedAtToActivityFlows < ActiveRecord::Migration[7.2]
  def change
    add_column :activity_flows, :completed_at, :datetime
  end
end
