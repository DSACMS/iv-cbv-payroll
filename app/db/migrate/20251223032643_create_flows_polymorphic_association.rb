class CreateFlowsPolymorphicAssociation < ActiveRecord::Migration[8.1]
  def change
    add_reference :payroll_accounts, :activity_flow, null: true, index: true
    add_column :payroll_accounts, :flow_type, :string
    rename_column :payroll_accounts, :cbv_flow_id, :flow_id
    add_index :payroll_accounts, [ :flow_type, :flow_id ]
  end
end
