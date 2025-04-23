# NOTE: only doing this in development as some production environments (Heroku)
# NOTE: are sensitive to local FS writes, and besides -- it's just not proper
# NOTE: to have a dev-mode tool do its thing in production.
if Rails.env.development?
  RailsERD.load_tasks

  # Monkeypatch the ERDGraph gem to only save the ERD when there are changes to
  # the schema version.
  class ERDGraph::Migration
    class << self
      alias_method :update_model_unpatched, :update_model

      def update_model
        version_file_path = File.expand_path(File.join(RailsERD.options[:filename], "../.database-diagram-schema-version"))
        current_schema_version = ActiveRecord::Migrator.current_version
        if File.read(version_file_path).to_i < current_schema_version
          update_model_unpatched

          File.open(version_file_path, "w") { |f| f.puts(current_schema_version) }
        else
          puts "Not rendering the ERD as it is already up-to-date."
        end
      end
    end
  end
end
