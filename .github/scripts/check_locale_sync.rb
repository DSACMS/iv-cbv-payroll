class LocaleSyncChecker
  require 'yaml'
  require 'open3'

  require_relative '../../app/services/locale_diff_service'

  def initialize
    @en_locale_path = 'app/config/locales/en.yml'
    @es_locale_path = 'app/config/locales/es.yml'
    @locale_diff_service = LocaleDiffService.new
  end

  def run
    puts "Checking locale synchronization against branch creation point..."

    en_changed_keys = @locale_diff_service.get_keys_needing_translation(@en_locale_path)
    es_changed_keys = @locale_diff_service.get_keys_needing_translation(@es_locale_path)

    puts "\n=== English Changed Keys ==="
    puts en_changed_keys.empty? ? "No changes" : en_changed_keys.join(", ")

    puts "\n=== Spanish Changed Keys ==="
    puts es_changed_keys.empty? ? "No changes" : es_changed_keys.join(", ")

    # Check if changes are synchronized
    if locales_synchronized?(en_changed_keys, es_changed_keys)
      puts "\n✅ SUCCESS: English and Spanish locales are synchronized!"
      exit 0
    else
      puts "\n❌ FAILURE: English and Spanish locales are not synchronized!"
      print_synchronization_issues(en_changed_keys, es_changed_keys)
      exit 1
    end
  end

  private

  def locales_synchronized?(en_changed_keys, es_changed_keys)
    en_keys_normalized = en_changed_keys.map { |key| remove_language_prefix(key) }.sort
    es_keys_normalized = es_changed_keys.map { |key| remove_language_prefix(key) }.sort
    en_keys_normalized == es_keys_normalized
  end

  def remove_language_prefix(key)
    # Remove 'en.' or 'es.' prefix from keys
    key.sub(/^(en|es)\./, '')
  end

  def print_synchronization_issues(en_changed_keys, es_changed_keys)
    puts "\n=== Synchronization Issues ==="

    en_keys_normalized = en_changed_keys.map { |key| remove_language_prefix(key) }
    es_keys_normalized = es_changed_keys.map { |key| remove_language_prefix(key) }

    missing_in_spanish = en_keys_normalized - es_keys_normalized
    missing_in_english = es_keys_normalized - en_keys_normalized

    unless missing_in_spanish.empty?
      puts "\n🔸 Keys changed in English but not in Spanish:"
      missing_in_spanish.each { |key| puts "  - #{key}" }
    end

    unless missing_in_english.empty?
      puts "\n🔸 Keys changed in Spanish but not in English:"
      missing_in_english.each { |key| puts "  - #{key}" }
    end

    puts "\n💡 To fix this, ensure that any changes to English locale keys"
    puts "   are also reflected in the corresponding Spanish locale keys."
  end
end

LocaleSyncChecker.new.run
