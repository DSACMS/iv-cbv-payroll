class AddEventsToCbvFlows < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_flows, :events, :string, array: true, default: []
  end
end
