namespace :db do
  desc "Create the PostgreSQL schema specified by DB_SCHEMA"
  task create_schema: :environment do
    schema = ENV["DB_SCHEMA"]
    abort("DB_SCHEMA must be set to a non-'public' value (got: #{schema.inspect})") if schema.blank? || schema == "public"

    ActiveRecord::Base.connection.execute(
      "CREATE SCHEMA IF NOT EXISTS #{ActiveRecord::Base.connection.quote_column_name(schema)}"
    )
    Rails.logger.info("Schema '#{schema}' created or already exists.")
  end

  desc "Drop the PostgreSQL schema specified by DB_SCHEMA"
  task drop_schema: :environment do
    schema = ENV["DB_SCHEMA"]
    abort("DB_SCHEMA must be set to a non-'public' value (got: #{schema.inspect})") if schema.blank? || schema == "public"

    ActiveRecord::Base.connection.execute(
      "DROP SCHEMA IF EXISTS #{ActiveRecord::Base.connection.quote_column_name(schema)} CASCADE"
    )
    Rails.logger.info("Schema '#{schema}' dropped.")
  end

  # Per-PR schemas are created by db:create_schema and owned by the migrator
  # user, so the runtime app user has no access by default. The role_manager
  # Lambda only configures grants for the env-level schema (e.g. "app"), not
  # per-PR schemas, so we grant here after migrations have created the tables.
  desc "Grant the app user privileges on DB_SCHEMA after migrations"
  task grant_app_access: :environment do
    schema = ENV["DB_SCHEMA"]
    app_user = ENV["APP_USER"]
    abort("DB_SCHEMA must be set to a non-'public' value (got: #{schema.inspect})") if schema.blank? || schema == "public"
    abort("APP_USER must be set (got: #{app_user.inspect})") if app_user.blank?

    conn = ActiveRecord::Base.connection
    quoted_schema = conn.quote_column_name(schema)
    quoted_user = conn.quote_column_name(app_user)

    conn.execute("GRANT USAGE ON SCHEMA #{quoted_schema} TO #{quoted_user}")
    conn.execute("GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA #{quoted_schema} TO #{quoted_user}")
    conn.execute("GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA #{quoted_schema} TO #{quoted_user}")
    conn.execute("ALTER DEFAULT PRIVILEGES IN SCHEMA #{quoted_schema} GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER ON TABLES TO #{quoted_user}")
    conn.execute("ALTER DEFAULT PRIVILEGES IN SCHEMA #{quoted_schema} GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO #{quoted_user}")
    Rails.logger.info("Granted app user '#{app_user}' privileges on schema '#{schema}'.")
  end
end
