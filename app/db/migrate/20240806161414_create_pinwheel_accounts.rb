class CreatePinwheelAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :pinwheel_accounts do |t|
      t.belongs_to :cbv_flow, null: false, foreign_key: true
      t.string :pinwheel_account_id
      t.timestamp :paystubs_synced_at
      t.timestamp :employment_synced_at
      t.timestamp :income_synced_at
      t.timestamps
    end
  end
end
