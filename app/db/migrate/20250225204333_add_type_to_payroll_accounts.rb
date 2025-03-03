class AddTypeToPayrollAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :pinwheel_accounts, :type, :string, null: false, default: "pinwheel"
  end
end
