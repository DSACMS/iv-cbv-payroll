class CreateFlowsPolymorphicAssociation < ActiveRecord::Migration[8.1]
  def change
    add_column :payroll_accounts, :flow_type, :string
    PayrollAccount.in_batches(of: 500).update_all(flow_type: "CbvFlow")
    rename_column :payroll_accounts, :cbv_flow_id, :flow_id
    add_index :payroll_accounts, [ :flow_type, :flow_id ]
  end
end
