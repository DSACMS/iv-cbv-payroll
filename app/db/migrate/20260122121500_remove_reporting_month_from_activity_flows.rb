# frozen_string_literal: true

class RemoveReportingMonthFromActivityFlows < ActiveRecord::Migration[8.1]
  def change
    remove_column :activity_flows, :reporting_month, :date
    remove_column :activity_flow_invitations, :reporting_month, :date
  end
end
