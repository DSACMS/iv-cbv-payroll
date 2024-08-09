class AddTransmittedAtToCbvFlows < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_flows, :transmitted_at, :datetime
  end
end
