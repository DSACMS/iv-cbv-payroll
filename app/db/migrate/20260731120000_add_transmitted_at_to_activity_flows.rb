class AddTransmittedAtToActivityFlows < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flows, :transmitted_at, :datetime
  end
end
