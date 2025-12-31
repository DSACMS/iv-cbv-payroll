class AddReportingMonthToActivityFlowInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flow_invitations, :reporting_month, :date
  end
end
