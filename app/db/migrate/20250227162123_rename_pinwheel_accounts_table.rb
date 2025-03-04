class RenamePinwheelAccountsTable < ActiveRecord::Migration[7.1]
  def change
    rename_table :pinwheel_accounts, :payroll_accounts
  end
end
