class AddPayrollAccountsToActivityFlows < ActiveRecord::Migration[8.1]
  def change
    add_reference :payroll_accounts, :activity_flow, null: true, index: true
    add_foreign_key :payroll_accounts, :activity_flows, column: :activity_flow_id
  end
end
