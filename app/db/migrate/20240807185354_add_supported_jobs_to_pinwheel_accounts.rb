class AddSupportedJobsToPinwheelAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :pinwheel_accounts, :supported_jobs, :string, array: true, default: []
  end
end
