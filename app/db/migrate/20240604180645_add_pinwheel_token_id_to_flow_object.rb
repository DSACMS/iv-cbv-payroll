class AddPinwheelTokenIdToFlowObject < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_flows, :pinwheel_token_id, :string
  end
end
