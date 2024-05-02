class CreateConnectedArgyleAccounts < ActiveRecord::Migration[7.0]
  def change
    create_table :connected_argyle_accounts, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.uuid :account_id, null: false
      t.datetime :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }

      t.index [:user_id, :account_id], unique: true
    end
  end
end
