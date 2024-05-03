class AddPayrollColumnToCbvFlows < ActiveRecord::Migration[7.0]
  def change
    add_column :cbv_flows, :payroll_data_available_from, :date
  end
end
