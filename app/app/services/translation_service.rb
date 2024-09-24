require "csv"
require "yaml"

class TranslationService
  def self.generate(csv_filename, output_yaml_path, options = {})
    csv_path = Rails.root.join(csv_filename)

    # Set default options
    target_locale = options.fetch(:target_locale, "es")
    middleware = options.fetch(:middleware, [])
    translations = { target_locale => {} }
    row_count = 0
    valid_translation_count = 0
    empty_row_count = 0
    skipped_rows = []

    Rails.logger.info "Attempting to read CSV file: #{csv_path}"
    csv_lines = File.readlines(csv_path)

    # Remove the first line if it contains the file label
    if csv_lines.first.strip.start_with?("SNAP Income Pilot Translations")
      csv_lines.shift
    end

    # Join the remaining lines to form the CSV content
    csv_content = csv_lines.join

    CSV.parse(csv_content, headers: true, header_converters: :symbol, skip_blanks: true).each_with_index do |row, index|
      # Skip the first row as it's a document header
      next if index == 0

      row_count += 1

      # Apply middleware
      next if middleware.any? { |fn| (row = fn.call(row)) == false }

      translation_key = row[:translation_key].to_s.strip
      translation_value = (row[target_locale.to_sym] || row[:spanish]).to_s.strip

      if translation_key.empty? || translation_value.empty?
        empty_row_count += 1
        next
      end

      # Remove 'en.' prefix if present
      translation_key = translation_key.delete_prefix("en.")

      Rails.logger.info "Row #{row_count}: Key: '#{translation_key}', Translation: '#{translation_value}'"
      set_nested_hash_value(translations[target_locale], translation_key.split("."), translation_value)
      valid_translation_count += 1
    end

    Rails.logger.info "Total rows processed: #{row_count}"
    Rails.logger.info "Valid translations found: #{valid_translation_count}"
    Rails.logger.info "Empty rows skipped: #{empty_row_count}"
    Rails.logger.info "Rows skipped by conditions: #{skipped_rows.count}"

    File.open(output_yaml_path, "w") do |file|
      file.write(translations.to_yaml(line_width: -1))  # Preserve line breaks in YAML
    end

    Rails.logger.info "#{target_locale} translations have been generated and saved to #{output_yaml_path}"
    translations
  end

  def self.skip_no_translation
    lambda do |row|
      row[:added_to_confluence]&.strip == "No need for translation"
    end
  end

  private

  def self.set_nested_hash_value(hash, keys, value)
    key = keys.shift
    if keys.empty?
      hash[key] = value
    else
      hash[key] ||= {}
      set_nested_hash_value(hash[key], keys, value)
    end
  end
end
