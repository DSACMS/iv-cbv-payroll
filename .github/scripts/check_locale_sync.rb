require 'yaml'
require 'open3'

require_relative '../../app/services/locale_diff_service'

class LocaleSyncChecker
  def initialize
    @en_locale_path = 'app/config/locales/en.yml'
    @es_locale_path = 'app/config/locales/es.yml'
    @locale_diff_service = LocaleDiffService.new
  end

  def run
    puts "Checking locale synchronization against branch creation point..."

    en_changed_keys, _ = @locale_diff_service.get_changed_keys_in_this_branch("en")
    es_changed_keys, _ = @locale_diff_service.get_changed_keys_in_this_branch("es")

    puts "\n=== English Changed Keys ==="
    puts en_changed_keys.empty? ? "No changes" : en_changed_keys.join(", ")

    puts "\n=== Spanish Changed Keys ==="
    puts es_changed_keys.empty? ? "No changes" : es_changed_keys.join(", ")

    en_changed_keys = en_changed_keys.map { |key| remove_language_prefix(key) }
    es_changed_keys = es_changed_keys.map { |key| remove_language_prefix(key) }

    en_filtered = filter_existing_keys(en_changed_keys)
    es_filtered = filter_existing_keys(es_changed_keys)

    puts "\n=== After filtering keys that exist in both locales ==="
    puts "English changes requiring sync: #{en_filtered.join(', ')}" unless en_filtered.empty?
    puts "Spanish changes requiring sync: #{es_filtered.join(', ')}" unless es_filtered.empty?

    if en_filtered.sort == es_filtered.sort
      puts "\n✅ SUCCESS: English and Spanish locales are synchronized!"
      exit 0
    else
      puts "\n❌ FAILURE: English and Spanish locales are not synchronized!"
      print_synchronization_issues(en_filtered, es_filtered)
      exit 1
    end
  end

  private

  def remove_language_prefix(key)
    puts "Normalizing key: #{key}"
    key.sub(/^(en|es)\./, '')
  end

  def filter_existing_keys(normalized_keys)
    current_diff = @locale_diff_service.get_current_locale_keys_diff
    
    # If both locales currently have the key, don't require sync
    normalized_keys.reject do |key|
      !current_diff[:missing_in_spanish].include?(key) && 
      !current_diff[:missing_in_english].include?(key)
    end
  end

  def print_synchronization_issues(en_changed_keys, es_changed_keys)
    puts "\n=== Synchronization Issues ==="

    missing_in_spanish = en_changed_keys - es_changed_keys
    missing_in_english = es_changed_keys - en_changed_keys

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
