class AddTypeToPayrollAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :payroll_accounts, :type, :string, null: false, default: "pinwheel"
  end
end
