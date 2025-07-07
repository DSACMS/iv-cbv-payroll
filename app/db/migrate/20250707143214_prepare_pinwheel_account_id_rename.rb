class PreparePinwheelAccountIdRename < ActiveRecord::Migration[7.1]
  def change
    add_column :payroll_accounts, :remote_account_id, :string

    PayrollAccount.where.not(pinwheel_account_id: nil).find_in_batches(batch_size: 1000) do |batch|
     PayrollAccount.where(id: batch).update_all("remote_account_id = pinwheel_account_id")
   end
  end
end
