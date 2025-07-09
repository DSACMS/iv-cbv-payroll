class RemoveUnusedFieldsFromPayrollAccount < ActiveRecord::Migration[7.1]
  def change
    remove_column :payroll_accounts, :paystubs_synced_at
    remove_column :payroll_accounts, :employment_synced_at
    remove_column :payroll_accounts, :employment_errored_at
    remove_column :payroll_accounts, :income_errored_at
    remove_column :payroll_accounts, :paystubs_errored_at
    remove_column :payroll_accounts, :identity_errored_at
    remove_column :payroll_accounts, :identity_synced_at
  end
end
