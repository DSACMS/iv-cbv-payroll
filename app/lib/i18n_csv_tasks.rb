# see: https://github.com/glebm/i18n-tasks/wiki/Custom-CSV-import-and-export-tasks
require "i18n/tasks/commands"
require "csv"
require "yaml"
module I18nCsvTasks
  include ::I18n::Tasks::Command::Collection

  IMPORT_FOLDER = File.join(File.dirname(__FILE__), "..", "tmp", "import")
  LOCALES_FOLDER = File.join(File.dirname(__FILE__), "..", "config", "locales")
  VERBOSE = false

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
    Dir.glob(File.join(IMPORT_FOLDER, "*.csv")).each do |file_path|
      puts "Processing: #{File.basename(file_path)}"

      csv_enum = open_csv_with_encoding(file_path)
      first_line = csv_enum.first

      unless valid_csv_header?(first_line)
        puts "  ERROR: CSV file '#{File.basename(file_path)}' does not have the expected header format. Expected 'key,en,*', got '#{first_line.join(", ")}'. Skipping import for this file."
        next
      end

      yml_file = File.join(LOCALES_FOLDER, "#{first_line[2].strip}.yml")
      unless File.file?(yml_file)
        puts "  ERROR: YAML output file '#{yml_file}' does not exist. Skipping import for this file."
        next
      end

      yaml_data = YAML.load_file(yml_file) || {}
      parse_csv_into_yaml(yaml_data, csv_enum, yml_file, file_path)

      File.write(yml_file, YAML.dump(yaml_data, line_width: -1), mode: "w:UTF-8")
    end
  end

  private

  def open_csv_with_encoding(file_path)
    # note: sometimes this line needs to detect windows UTF-8 encodings depending on
    # how the csv file was saved.
    # encodings = [ "Windows-1252:UTF-8", "UTF-8" ]
    encodings = [ "UTF-8" ]
    encodings.each do |enc|
      begin
        File.open(file_path, "r:#{enc}") do |file|
          CSV.new(file).first
          return CSV.new(File.open(file_path, "r:#{enc}"), headers: false)
        end
      rescue
        puts "  Failed to read CSV with encoding #{enc}. Trying next..." if VERBOSE
      end
    end
    raise "  ERROR: Could not read CSV file in a supported encoding."
  end

  def set_nested_value(hash, path_array, value)
    return if path_array.empty?
    key = path_array.shift

    if path_array.empty?
      hash[key] = value
    else
      hash[key] = {} unless hash[key].is_a?(Hash)
      set_nested_value(hash[key], path_array, value)
    end
  end

  def parse_csv_into_yaml(yaml_data, csv_enum, yml_file, file)
    merged_count = 0
    skipped_count = 0
    problematic_entries = []

    csv_enum.each do |row|
      next if row.nil? || row.all?(&:nil?)
      path = row[0]&.strip
      translation = row[2]

      if path.nil? || path.empty?
        puts "  WARNING: Skipping row: Invalid path. Path: '#{path}', Translation: '#{translation}'"
        skipped_count += 1
        problematic_entries << row
        next
      end

      if translation.nil?
        puts "  Skipping row: No translation provided. Path: '#{path}', Translation: '#{translation}'" if VERBOSE
        skipped_count += 1
        next
      end

      path_segments = path.split(".")
      path_segments.unshift("es") unless path_segments.first == "es"
      puts "  Modifying '#{path}' with translation '#{translation}'" if VERBOSE
      set_nested_value(yaml_data, path_segments.map(&:to_s), translation)
      merged_count += 1
    rescue => e
      puts "  ERROR processing row: #{row.inspect}\n    Exception: #{e.message}\n#{e.backtrace.join("\n")}"
      problematic_entries << row
      skipped_count += 1
    end

    puts "  Merged #{merged_count} entries, skipped #{skipped_count}."
    puts "  Done! YAML file '#{yml_file}' has been updated with translations from '#{file}'."
  end

  def valid_csv_header?(header)
    header && header[0] == "key" && header[1] == "en" && !header[2].nil?
  end
end

I18n::Tasks.add_commands I18nCsvTasks
