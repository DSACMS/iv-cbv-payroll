class AddReportingMonthToActivityFlows < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flows, :reporting_month, :date
  end
end
