class AddErrorEventColumnForIdentity < ActiveRecord::Migration[7.1]
  def change
    add_column :pinwheel_accounts, :identity_errored_at, :timestamp
    add_column :pinwheel_accounts, :identity_synced_at, :timestamp
  end
end
