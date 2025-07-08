class PreparePinwheelAccountIdRename < ActiveRecord::Migration[7.1]
  def change
    add_column :payroll_accounts, :aggregator_account_id, :string
  end
end
