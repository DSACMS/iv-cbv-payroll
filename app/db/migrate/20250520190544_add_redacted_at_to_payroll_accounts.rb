class AddRedactedAtToPayrollAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :payroll_accounts, :redacted_at, :datetime
  end
end
