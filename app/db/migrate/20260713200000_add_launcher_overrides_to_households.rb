class AddLauncherOverridesToHouseholds < ActiveRecord::Migration[8.1]
  def change
    add_column :households, :launcher_overrides, :jsonb, default: {}, null: false
  end
end
