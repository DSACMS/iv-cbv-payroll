class AddGigsSynced < ActiveRecord::Migration[7.1]
  def change
    add_column :payroll_accounts, :gigs_synced_at, :timestamp
  end
end
