class AddArgyleUserIdToCbvFlows < ActiveRecord::Migration[7.1]
  def change
    change_table :cbv_flows do |t|
      t.string :argyle_user_id
    end
  end
end
