class AddEndUserIdColumnToCbvFlows < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_flows, :pinwheel_end_user_id, :uuid, default: 'gen_random_uuid()', null: false
  end
end
