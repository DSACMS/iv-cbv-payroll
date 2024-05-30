class UpdateTablePermissions < ActiveRecord::Migration[7.0]
  def change
    execute "ALTER DEFAULT PRIVILEGES GRANT ALL ON TABLES TO app"
  end
end
