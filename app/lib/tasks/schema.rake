namespace :db do
  desc "Create the PostgreSQL schema specified by DB_SCHEMA"
  task create_schema: :environment do
    schema = ENV["DB_SCHEMA"]
    if schema.present? && schema != "public"
      ActiveRecord::Base.connection.execute(
        "CREATE SCHEMA IF NOT EXISTS #{ActiveRecord::Base.connection.quote_column_name(schema)}"
      )
      Rails.logger.info("Schema '#{schema}' created or already exists.")
    end
  end

  desc "Drop the PostgreSQL schema specified by DB_SCHEMA"
  task drop_schema: :environment do
    schema = ENV["DB_SCHEMA"]
    if schema.present? && schema != "public"
      ActiveRecord::Base.connection.execute(
        "DROP SCHEMA IF EXISTS #{ActiveRecord::Base.connection.quote_column_name(schema)} CASCADE"
      )
      Rails.logger.info("Schema '#{schema}' dropped.")
    end
  end
end
