class AddJsonTransmittedAtToCbvFlows < ActiveRecord::Migration[8.1]
  def up
    add_column :cbv_flows, :json_transmitted_at, :datetime

    # Backfill json_transmitted_at for existing records that have been transmitted
    # We use transmitted_at as the best approximation of when JSON was successfully sent
    CbvFlow.where.not(transmitted_at: nil).update_all("json_transmitted_at = transmitted_at")
  end

  def down
    remove_column :cbv_flows, :json_transmitted_at
  end
end
