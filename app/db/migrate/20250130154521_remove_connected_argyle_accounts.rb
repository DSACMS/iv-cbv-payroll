class RemoveConnectedArgyleAccounts < ActiveRecord::Migration[7.1]
  def change
    drop_table :connected_argyle_accounts
    
    remove_column :cbv_flows, :argyle_user_id
  end
end
