# see https://github.com/navapbc/template-infra/blob/main/docs/infra/set-up-database.md#important-note-on-postgres-table-permissions
class SetDbTablePermissions < ActiveRecord::Migration[7.0]
  def change
    # This is only useful to fix permissions in deploy environments.
    # In development: do nothing.
    return if Rails.env.development?

    execute <<-SQL
      ALTER DEFAULT PRIVILEGES GRANT ALL ON TABLES TO app
    SQL

    execute <<-SQL
      ALTER DEFAULT PRIVILEGES GRANT ALL ON SEQUENCES TO app
    SQL

    execute <<-SQL
      ALTER DEFAULT PRIVILEGES GRANT ALL ON ROUTINES TO app
    SQL
  end
end
