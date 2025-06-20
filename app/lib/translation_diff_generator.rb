require "yaml"
require "csv"

require_relative "../services/locale_diff_service"

class TranslationDiffGenerator
  TARGET_LANGUAGE_CODE = "es"
  OUTPUT_CSV_PATH = "translation_update.csv"

  def initialize
    @locale_diff_service = LocaleDiffService.new
    @project_root = @locale_diff_service.project_root

    puts "Configuration:"
    puts " - Comparing against branch: #{LocaleDiffService::BASE_BRANCH}"
    puts " - English locale: #{LocaleDiffService::EN_LOCALE_PATH}"
    puts " - Output file: #{OUTPUT_CSV_PATH}"
    puts "--------------------------------------------------"
  end

  def generate_csv
    puts "1. Fetching old `en.yml` from common ancestor..."
    old_en_yaml_content = @locale_diff_service.get_en_content_from_common_ancestor
    return unless old_en_yaml_content

    old_en_hash = YAML.safe_load(old_en_yaml_content) || {}

    puts "2. Loading current locale files from your branch..."
    current_en_hash = @locale_diff_service.load_yaml_file(File.join(@project_root, LocaleDiffService::EN_LOCALE_PATH))

    # Flatten the hashes to make them easy to compare (e.g., { "en.users.show.title" => "User Profile" }).
    flat_old_en = @locale_diff_service.flatten_hash(old_en_hash)
    flat_current_en = @locale_diff_service.flatten_hash(current_en_hash)

    puts "3. Comparing versions to find new or modified strings..."
    keys_to_translate = @locale_diff_service.find_changed_keys(flat_old_en, flat_current_en)

    if keys_to_translate.empty?
      puts "✅ No new or modified English keys found. You're all set!"
      return
    end

    puts "Found #{keys_to_translate.count} keys that are new or modified."

    puts "4. Translating strings to `#{TARGET_LANGUAGE_CODE}` and generating CSV..."
    create_csv(keys_to_translate, flat_current_en)

    puts "\n🎉 Success! CSV file created at: #{OUTPUT_CSV_PATH}"
    puts "Please review the file and send it to your translation service."
  rescue StandardError => e
    puts "\n💥 An unexpected error occurred:"
    puts e.message
    puts e.backtrace
  end

  private

  def create_csv(keys, english_strings)
    progress_bar_length = 50
    total_keys = keys.count

    CSV.open(File.join(@project_root, OUTPUT_CSV_PATH), "w") do |csv|
      csv << [ "key", "en", TARGET_LANGUAGE_CODE ] # CSV Header

      keys.each_with_index do |key, index|
        english_text = english_strings[key]

        # Skip non-string values (e.g., YAML aliases, booleans)
        unless english_text.is_a?(String) && !english_text.empty?
          puts "Skipping non-string or empty key: #{key}"
          next
        end

        # We remove the top-level language key (e.g., 'en.') for the final CSV.
        key_for_csv = key.split(".", 2).last

        csv << [ key_for_csv, english_text ]

        progress = (index + 1).to_f / total_keys
        filled_length = (progress * progress_bar_length).to_i
        bar = "█" * filled_length + "-" * (progress_bar_length - filled_length)
        print "\rProgress: [#{bar}] #{(progress * 100).to_i}%"
      end
    end
  end
end
