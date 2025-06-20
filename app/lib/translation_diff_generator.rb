require "yaml"
require "csv"
require "rainbow"

require_relative "../services/locale_diff_service"

class TranslationDiffGenerator
  TARGET_LANGUAGE_CODE = "es"
  OUTPUT_CSV_PATH = "translation_update.csv"

  def initialize
    @locale_diff_service = LocaleDiffService.new
    @project_root = @locale_diff_service.project_root

    puts Rainbow("Configuration:").bright
    puts " - English locale: #{Rainbow(LocaleDiffService::EN_LOCALE_PATH).cyan}"
    puts " - Output file: #{Rainbow(OUTPUT_CSV_PATH).cyan}"
    puts "--------------------------------------------------"
  end

  def generate_csv
    changed_keys, flat_current = @locale_diff_service.get_changed_keys_in_this_branch("en")

    if changed_keys.empty?
      puts Rainbow("✅ No new or modified English keys found. You're all set!").green
      return
    end

    puts Rainbow("Found #{changed_keys.count} keys that are new or modified.").yellow

    puts "Generating CSV..."
    write_csv(changed_keys, flat_current)

    puts Rainbow("\n🎉 Success! CSV file created at: #{OUTPUT_CSV_PATH}").green
    puts "Please review the file and send it to your translation service."
  rescue StandardError => e
    puts Rainbow("\n💥 An unexpected error occurred:").red
    puts e.message
    puts e.backtrace
  end

  private

  def write_csv(keys, english_strings)
    progress_bar_length = 50
    total_keys = keys.count

    CSV.open(File.join(@project_root, OUTPUT_CSV_PATH), "w") do |csv|
      csv << [ "key", "en", TARGET_LANGUAGE_CODE ] # CSV Header

      keys.each_with_index do |key, index|
        english_text = english_strings[key]

        # Skip non-string values (e.g., YAML aliases, booleans)
        unless english_text.is_a?(String) && !english_text.empty?
          puts Rainbow("Skipping non-string or empty key: #{key}").magenta
          next
        end

        # We remove the top-level language key (e.g., 'en.') for the final CSV.
        key_for_csv = key.split(".", 2).last

        csv << [ key_for_csv, english_text ]

        progress = (index + 1).to_f / total_keys
        filled_length = (progress * progress_bar_length).to_i
        bar = "█" * filled_length + "-" * (progress_bar_length - filled_length)
        print "\rProgress: [#{Rainbow(bar).green}] #{(progress * 100).to_i}%"
      end
    end
  end
end
