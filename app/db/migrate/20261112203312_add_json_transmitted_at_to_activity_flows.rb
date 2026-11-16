class AddJsonTransmittedAtToActivityFlows < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flows, :json_transmitted_at, :datetime
  end
end
