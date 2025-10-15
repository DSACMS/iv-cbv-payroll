class RemovePinwheelAccountIdFromPayrollAccounts < ActiveRecord::Migration[7.2]
  def change
    remove_column :payroll_accounts, :pinwheel_account_id, :string
  end
end
