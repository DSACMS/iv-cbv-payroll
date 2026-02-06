# frozen_string_literal: true

class AddDataSourceToPayrollAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :payroll_accounts, :data_source, :string, default: "validated", null: false
  end
end
