class AddErrorEventsToPinwheelAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :pinwheel_accounts, :employment_errored_at, :timestamp
    add_column :pinwheel_accounts, :income_errored_at, :timestamp
    add_column :pinwheel_accounts, :paystubs_errored_at, :timestamp
  end
end
