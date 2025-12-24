class RemoveForeignKeyConstraintOnPayrollAccounts < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :payroll_accounts, :cbv_flows, if_exists: true
  end
end
