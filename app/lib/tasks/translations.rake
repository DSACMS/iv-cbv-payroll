namespace :translations do
  desc "Import locale translations from CSV to YAML"
  task :import, [ :locale, :overwrite ] => :environment do |t, args|
    locale = args[:locale]

    if locale.nil?
      puts "Please provide a locale argument. Example: rake translations:import[es]"
      exit
    end

    overwrite = args[:overwrite] == "true"
    puts "Task started for locale: #{locale}"
    puts "Overwrite mode: #{overwrite}"

    csv_dir = Rails.root.join("tmp")
    csv_files = Dir.glob(csv_dir.join("#{locale}_import*.csv")).sort_by { |f| File.mtime(f) }

    if csv_files.empty?
      puts "No CSV files found matching the pattern #{locale}_import*.csv in #{csv_dir}"
      exit
    end

    latest_csv = csv_files.last
    puts "Using the latest CSV file: #{latest_csv}"

    output_yaml_path = Rails.root.join("config", "locales", "#{locale}.yml")
    puts "Output YAML path: #{output_yaml_path}"

    service = TranslationService.new(locale, overwrite)
    puts "Service initialized"

    service.generate(latest_csv, output_yaml_path)

    puts "#{locale.upcase} translations have been imported from #{latest_csv} and saved to #{output_yaml_path}"
  end
end
