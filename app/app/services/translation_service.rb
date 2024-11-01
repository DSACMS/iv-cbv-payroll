require "csv"
require "yaml"

class TranslationService
  attr_reader :results

  def initialize(locale = "es", overwrite = false)
    @locale = locale
    @overwrite = overwrite
    @existing_translations = load_existing_translations
    @current_locale_translations = load_current_locale_translations
    @results = {
      rows: [],
      empty_row_count: 0,
      skipped_rows: [],
      failed_imports: [],
      successful_imports: 0,
      collisions: []
    }
  end

  def generate(csv_path, output_yaml_path)
    translations = @current_locale_translations.deep_dup
    Rails.logger.info "Attempting to read CSV file: #{csv_path}"
    csv_content = File.read(csv_path)

    process_csv(csv_content, translations[@locale])

    log_results
    write_yaml(translations, output_yaml_path)

    Rails.logger.info "#{@locale} translations have been generated and saved to #{output_yaml_path}"
    translations
  end

  private

  def process_csv(csv_content, translations)
    CSV.parse(csv_content, headers: true, header_converters: :symbol).each do |row|
      if skip_row?(row)
        @results[:skipped_rows] << row
        next
      end

      process_row(row, translations)
    end
  end

  def process_row(row, translations)
    translation_key = row[:key].to_s.strip
    translation_value = (row[@locale.to_sym]).to_s.strip

    if translation_value.empty?
      @results[:empty_row_count] += 1
      return
    end

    lookup_key = translation_key.sub(/^en\./, "")

    unless @existing_translations["en"].dig(*lookup_key.split("."))
      @results[:failed_imports] << { key: translation_key, reason: "English key does not exist" }
      Rails.logger.warn "Warning: English key '#{translation_key}' does not exist in the current en.yml file"
      return
    end

    existing_value = translations.dig(*lookup_key.split("."))
    if existing_value && existing_value != translation_value
      if @overwrite
        Rails.logger.warn "Overwriting existing translation for key '#{lookup_key}'"
      else
        @results[:collisions] << { key: lookup_key, old_value: existing_value, new_value: translation_value }
        Rails.logger.warn "Collision detected for key '#{lookup_key}'. Keeping existing translation."
        return
      end
    end

    translation_value = translation_value.gsub(/\s+/, " ").strip

    set_nested_hash_value(translations, lookup_key.split("."), translation_value)
    @results[:rows] << row
    @results[:successful_imports] += 1
    Rails.logger.info "Processing: Key: '#{lookup_key}', Translation: '#{translation_value}'"
  end

  def skip_row?(row)
    return true if row[:key].to_s.strip.empty?
    return true if row[:es].to_s.strip.empty?

    false
  end

  def log_results
    total = @results.values.sum { |v| v.is_a?(Array) ? v.count : v }
    Rails.logger.info "Total rows processed: #{total}"
    Rails.logger.info "Successfully Imported: #{@results[:successful_imports]}"
    Rails.logger.info "Empty rows skipped: #{@results[:empty_row_count]}"
    Rails.logger.info "Rows skipped by conditions: #{@results[:skipped_rows].count}"
    Rails.logger.info "Failed imports: #{@results[:failed_imports].count}"
    Rails.logger.info "Collisions detected: #{@results[:collisions].count}"

    if @results[:failed_imports].any?
      Rails.logger.info "\nFailed Imports Details:"
      @results[:failed_imports].each do |failed|
        Rails.logger.info "  - Key: #{failed[:key]}, Reason: #{failed[:reason]}"
      end
    end

    if @results[:collisions].any?
      Rails.logger.info "\nCollisions Details:"
      collision_messages = @results[:collisions].map do |collision|
        "Key: #{collision[:key]}, Old Value: #{collision[:old_value]}, New Value: #{collision[:new_value]}"
      end
      Rails.logger.info collision_messages.join("\n")
    end
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
    formatted_translations = format_translations(translations)
    File.open(output_yaml_path, "w") do |file|
      file.write(formatted_translations.to_yaml)
    end
  end

  def format_translations(translations)
    translations.deep_transform_values do |value|
      value.is_a?(String) ? value.gsub(/\s+/, " ").strip : value
    end
  end

  def load_existing_translations
    YAML.load_file(Rails.root.join("config", "locales", "en.yml"))
  end

  def load_current_locale_translations
    file_path = Rails.root.join("config", "locales", "#{@locale}.yml")
    File.exist?(file_path) ? YAML.load_file(file_path) : { @locale => {} }
  end
end
