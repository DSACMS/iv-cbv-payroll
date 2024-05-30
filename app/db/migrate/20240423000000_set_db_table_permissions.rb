# see https://github.com/navapbc/template-infra/blob/main/docs/infra/set-up-database.md#important-note-on-postgres-table-permissions
class SetDbTablePermissions < ActiveRecord::Migration[7.0]
  def change
    execute <<-SQL
      ALTER DEFAULT PRIVILEGES GRANT ALL ON TABLES TO app
    SQL
  end
end
