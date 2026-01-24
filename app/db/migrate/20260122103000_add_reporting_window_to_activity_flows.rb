# frozen_string_literal: true

class AddReportingWindowToActivityFlows < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flows, :reporting_window_type, :string
    add_column :activity_flows, :reporting_window_months, :integer
  end
end
