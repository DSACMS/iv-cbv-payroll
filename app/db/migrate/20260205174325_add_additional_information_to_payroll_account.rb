class AddAdditionalInformationToPayrollAccount < ActiveRecord::Migration[8.1]
  def change
    add_column :payroll_accounts, :additional_information, :string
  end
end
