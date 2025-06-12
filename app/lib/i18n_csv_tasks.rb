# see: https://github.com/glebm/i18n-tasks/wiki/Custom-CSV-import-and-export-tasks
require "i18n/tasks/commands"
require "csv"
require "yaml"

VERBOSE = true
module I18nCsvTasks
  include ::I18n::Tasks::Command::Collection
  cmd :csv_export, desc: "export translations to CSV"
  def csv_export(opts = {})
    translations_by_path = {}
    router = I18n::Tasks::Data::Router::PatternRouter.new(nil, write: i18n.config["csv"]["export"])

    i18n.locales.each do |locale|
      router.route(locale, i18n.data_forest) do |path, nodes|
        translations_by_path[path] ||= {}
        translations_by_path[path][locale] ||= {}

        nodes.leaves do |node|
          translations_by_path[path][locale][node.full_key(root: false)] = node.value
        end
      end
    end

    translations_by_path.each do |(path, translations_by_locale)|
      FileUtils.mkdir_p(File.dirname(path))

      CSV.open(path, "wb") do |csv|
        csv << ([ "key" ] + i18n.locales)

        translations_by_locale[i18n.base_locale].keys.each do |key|
          values = i18n.locales.map do |locale|
            translations_by_locale[locale][key]
          end
          csv << values.unshift(key)
        end
      end
    end
  end

  cmd :csv_import, desc: "import translations from CSV"
  def csv_import(opts = {})
    def open_csv_with_encoding(file_path)
      # Try Windows-1252 (commonly used for CSVs exported from Excel), then UTF-8
      encodings = [ "Windows-1252:UTF-8", "UTF-8" ]
      encodings.each do |enc|
        begin
          File.open(file_path, "r:#{enc}") do |file|
            # Try reading the header to see if encoding works
            CSV.new(file).first
            return CSV.new(File.open(file_path, "r:#{enc}"), headers: false)
          end
        rescue
          puts "  Failed to read CSV with encoding #{enc}. Trying next..." if VERBOSE
          next
        end
      end
      raise "  ERROR: Could not read CSV file in a supported encoding."
    end

    def set_nested_value(hash, path_array, value)
      return if path_array.empty?

      if path_array.length == 1
        # Final key in the path (eg [es, cbv, successes, show, header], we're at 'header')
        key = path_array[0]
        if hash.key?(key)
          if hash[key] != value
            puts "  Replacing value at '#{path_array.join('.')}'. Old: #{hash[key].inspect}, New: #{value.inspect}"
            hash[key] = value
          else
            puts "  Value at '#{path_array.join('.')}' is already up-to-date." if VERBOSE
          end
        else
          hash[key] = value
        end
      else
        current_key = path_array[0]
        hash[current_key] ||= {}

        if !hash[current_key].is_a?(Hash)
          puts "  WARNING: Creating new nested level at '#{current_key}'. Old: #{hash[current_key]}"
          hash[current_key] = {}
        end

        set_nested_value(hash[current_key], path_array[1..-1], value)
      end
    end

    import_folder = File.join(File.dirname(__FILE__), "import")
    locales_folder = File.join(File.dirname(__FILE__), "..", "config", "locales")

    Dir.foreach(import_folder) do |file|
      next unless file.end_with?(".csv")
      file_path = File.join(import_folder, file)
      next unless File.file?(file_path)

      puts "Processing: #{file}"

      processed_count = 0
      skipped_count = 0
      problematic_entries = []
      csv_enum = open_csv_with_encoding(file_path)

      # Validate that the first line is properly formatted
      first_line = csv_enum.first
      if first_line[0] != "key" || first_line[1] != "en" || first_line[2].nil?
        puts "  ERROR: CSV file '#{file}' does not have the expected header format. Expected 'key,en,*'"
        next
      end

      # Validate that we can find the output YAML file
      yml_file = File.join(locales_folder, first_line[2].strip + ".yml")
      if !File.file?(yml_file)
        puts "  ERROR: YAML output file '#{yml_file}' does not exist. Skipping import for this file."
        next
      end

      puts "Processing CSV file: #{file}"

      yaml_data = YAML.load_file(yml_file) || {}

      csv_enum.each do |row|
        begin
          # Skip empty rows
          next if row.nil? || row.all?(&:nil?)

          path = row[0]&.strip
          translation = row[2]

          if path.nil? || path.empty?
            puts "  WARNING: Skipping row: Invalid path. Path: '#{path}', Translation: '#{translation}'"
            skipped_count += 1
            problematic_entries << row
            next
          end

          # This is pretty normal; if there's no translation it means we didn't want to change it.
          if translation.nil?
            puts "  Skipping row: No translation provided. Path: '#{path}', Translation: '#{translation}'" if VERBOSE
            skipped_count += 1
            next
          end

          path_segments = path.split(".")

          # Always prepend "es" as the top-level key (this is not always present in our exports)
          path_segments.unshift("es") unless path_segments.first == "es"

          if path_segments.empty?
            puts "  WARNING: Skipping row: Path has no segments: '#{path}'"
            skipped_count += 1
            problematic_entries << row
            next
          end

          path_segments = path_segments.map(&:to_s)
          puts "  Processing: Path: #{path_segments.join('.')}, Translation: #{translation[0..30]}..." if VERBOSE

          set_nested_value(yaml_data, path_segments, translation)
          processed_count += 1
        rescue => e
          puts "  ERROR processing row: #{row.inspect}\nException: #{e.message}\n#{e.backtrace.join("\n")}"
          problematic_entries << row
          skipped_count += 1
        end
      end

      # Write the updated YAML back to the file with proper encoding
      File.open(yml_file, "w:UTF-8") do |file|
        file.write(yaml_data.to_yaml)
      end

      puts "  Processed: #{processed_count}" if VERBOSE
      puts "  Skipped:   #{skipped_count}" if VERBOSE
      puts "  Done! YAML file '#{yml_file}' has been updated with translations from '#{file}'."
    end
  end
end
I18n::Tasks.add_commands I18nCsvTasks
