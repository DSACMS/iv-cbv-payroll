class AddPayrollConsentToActivityFlows < ActiveRecord::Migration[8.0]
  def change
    add_column :activity_flows, :payroll_consented_at, :datetime
  end
end
