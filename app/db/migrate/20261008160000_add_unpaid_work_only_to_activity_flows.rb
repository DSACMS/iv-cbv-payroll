class AddUnpaidWorkOnlyToActivityFlows < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flow_invitations, :unpaid_work_only, :boolean, default: false
    add_column :activity_flows, :unpaid_work_only, :boolean, default: false
  end
end
