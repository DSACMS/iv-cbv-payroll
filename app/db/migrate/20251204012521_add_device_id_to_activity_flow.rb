class AddDeviceIdToActivityFlow < ActiveRecord::Migration[7.2]
  def change
    add_column :activity_flows, :device_id, :string
  end
end
