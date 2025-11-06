class AddDeviceIdToCbvFlows < ActiveRecord::Migration[7.2]
  def change
    add_column :cbv_flows, :device_id, :string
  end
end
