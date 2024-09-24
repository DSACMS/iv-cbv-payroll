require "csv"
require "yaml"

class TranslationService
  def self.generate(csv_filename, output_yaml_path, options = {})
    csv_path = Rails.root.join(csv_filename)

    # Set default options
    target_locale = options.fetch(:target_locale, "es")
    skip_row_conditions = options.fetch(:skip_row_conditions, [
      self.skip_no_translation
    ])

    row_modifiers = options.fetch(:row_modifiers, [])
    translations = { target_locale => {} }
    row_count = 0
    valid_translation_count = 0
    empty_row_count = 0
    skipped_rows = []

    puts "Attempting to read CSV file: #{csv_path}"
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

      # Apply row modifiers
      row_modifiers.each do |modifier|
        row = modifier.call(row)
      end

      # Check skip conditions
      if skip_row_conditions.any? { |condition| condition.call(row) }
        skipped_rows << row
        next
      end

      translation_key = row[:translation_key]
      translation_value = row[target_locale.to_sym] || row[:spanish]  # Default to :spanish if specific locale column not found

      if translation_key.nil? || translation_value.nil? || translation_key.to_s.strip.empty? || translation_value.to_s.strip.empty?
        empty_row_count += 1
        next
      end

      # Remove 'en.' prefix if present
      if translation_key.start_with?("en.")
        translation_key = translation_key[3..-1]  # Remove the 'en.' prefix
      end

      puts "Row #{row_count}: Key: '#{translation_key}', Translation: '#{translation_value}'"
      set_nested_hash_value(translations[target_locale], translation_key.split("."), translation_value)
      valid_translation_count += 1
    end

    puts "Total rows processed: #{row_count}"
    puts "Valid translations found: #{valid_translation_count}"
    puts "Empty rows skipped: #{empty_row_count}"
    puts "Rows skipped by conditions: #{skipped_rows.count}"

    File.open(output_yaml_path, "w") do |file|
      file.write(translations.to_yaml(line_width: -1))  # Preserve line breaks in YAML
    end

    puts "#{target_locale} translations have been generated and saved to #{output_yaml_path}"
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
