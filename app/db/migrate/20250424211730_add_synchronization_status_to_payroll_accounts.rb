class AddSynchronizationStatusToPayrollAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :payroll_accounts, :synchronization_status, :string, default: "unknown"
  end
end
