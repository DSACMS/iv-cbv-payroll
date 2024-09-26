require "csv"
require "yaml"

class SpanishTranslationService
  attr_reader :rows, :empty_row_count, :skipped_rows
  TARGET_LOCALE = "es"

  def initialize
    @rows = []
    @empty_row_count = 0
    @skipped_rows = []
  end

  def generate(csv_filename, output_yaml_path)
    csv_path = Rails.root.join(csv_filename)

    # Set default options
    translations = { TARGET_LOCALE => {} }

    Rails.logger.info "Attempting to read CSV file: #{csv_path}"
    csv_content = File.read(csv_path)

    # Remove the first line if it contains the file label
    csv_content = csv_content.lines[1..-1].join if csv_content.lines.first.strip.start_with?("SNAP Income Pilot Translations")

    CSV.parse(csv_content, headers: true, header_converters: :symbol).each_with_index do |row, index|
      # skip the header row
      next if index.zero?

      if skip_row?(row)
        @skipped_rows << row
        next
      end

      process_row(row, translations[TARGET_LOCALE], TARGET_LOCALE)
    end

    log_results
    write_yaml(translations, output_yaml_path)

    Rails.logger.info "#{TARGET_LOCALE} translations have been generated and saved to #{output_yaml_path}"
    translations
  end

  private

  def process_row(row, translations, target_locale)
    translation_key = row[:translation_key].to_s.strip.delete_prefix("en.")
    translation_value = (row[target_locale.to_sym] || row[:spanish]).to_s.strip

    if translation_value.empty?
      @empty_row_count += 1
      return
    end

    translation_value = translation_value.split("\n").map(&:strip).join("\n") if translation_value.include?("\n")

    set_nested_hash_value(translations, translation_key.split("."), translation_value)
    @rows << row
    Rails.logger.info "Processing: Key: '#{translation_key}', Translation: '#{translation_value}'"
  end

  def skip_row?(row)
    return true if row[:translation_key].to_s.strip.empty?
    return true if row[:added_to_confluence]&.strip == "No need for translation"

    false
  end

  def log_results
    total = @rows.count + @empty_row_count + @skipped_rows.count
    puts "Total rows processed: #{total}"
    puts "Valid translations found: #{@rows.count}"
    puts "Empty rows skipped: #{@empty_row_count}"
    puts "Rows skipped by conditions: #{@skipped_rows.count}"
  end

  def set_nested_hash_value(hash, keys, value)
    key = keys.shift
    if keys.empty?
      hash[key] = value
    else
      hash[key] ||= {}
      set_nested_hash_value(hash[key], keys, value)
    end
  end

  def write_yaml(translations, output_yaml_path)
    File.open(output_yaml_path, "w") { |file| file.write(translations.to_yaml) }
  end
end
