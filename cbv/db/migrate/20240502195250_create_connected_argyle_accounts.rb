class CreateConnectedArgyleAccounts < ActiveRecord::Migration[7.0]
  def change
    create_table :connected_argyle_accounts do |t|
      t.uuid :user_id, null: false
      t.uuid :account_id, null: false
      t.timestamps null: false
      t.index [ :user_id, :account_id ], unique: true
    end
  end
end
