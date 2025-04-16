class RemoveGigsSyncedAt < ActiveRecord::Migration[7.1]
  def change
    # This column was created with a migration, but was mistakenly never
    # checked into the db/schema.rb file. So, any local (dev) database that has
    # been recreated from `rails db:schema:load` will not have the column.
    return unless column_exists?(:payroll_accounts, :gigs_synced_at)

    remove_column :payroll_accounts, :gigs_synced_at
  end
end
