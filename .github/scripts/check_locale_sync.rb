require 'yaml'
require 'open3'
require 'i18n/tasks'

require_relative '../../app/services/locale_diff_service'

class LocaleSyncChecker
  I18N_CONFIG_FILE = "config/i18n-tasks.yml" # relative to "app" directory

  def initialize
    @en_locale_path = 'app/config/locales/en.yml'
    @es_locale_path = 'app/config/locales/es.yml'
    @locale_diff_service = LocaleDiffService.new
  end

  def run
    puts "Checking locale synchronization against branch creation point..."

    en_changed_keys, _ = @locale_diff_service.get_changed_keys_in_this_branch("en")
    en_ignored_keys    = remove_ignored_keys!(en_changed_keys)
    es_changed_keys, _ = @locale_diff_service.get_changed_keys_in_this_branch("es")
    es_ignored_keys    = remove_ignored_keys!(es_changed_keys)

    puts "\n=== English Changed Keys ==="
    puts en_changed_keys.empty? ? "No changes" : en_changed_keys.join(", ")

    puts "\n=== Spanish Changed Keys ==="
    puts es_changed_keys.empty? ? "No changes" : es_changed_keys.join(", ")

    if en_ignored_keys.any? || es_ignored_keys.any?
      puts "\n=== Changed keys that are ignored (therefore considered synchronized) ==="
      puts en_ignored_keys.join(", ")
      puts es_ignored_keys.join(", ")
    end

    en_changed_keys = en_changed_keys.map { |key| remove_language_prefix(key) }
    es_changed_keys = es_changed_keys.map { |key| remove_language_prefix(key) }

    puts "\n=== Synchronization Status ==="
    if en_changed_keys == es_changed_keys
      puts "\n✅ SUCCESS: English and Spanish locales are synchronized!"
      exit 0
    else
      puts "\n❌ FAILURE: English and Spanish locales are not synchronized!"
      print_synchronization_issues(en_changed_keys, es_changed_keys)
      exit 1
    end
  end

  private

  def remove_language_prefix(key)
    key.sub(/^(en|es)\./, '')
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

  # Removes English keys that are ignored in Spanish.
  def remove_ignored_keys!(list_of_keys)
    Dir.chdir("app") do
      i18n_tasks = I18n::Tasks::BaseTask.new(config_file: I18N_CONFIG_FILE)
      list_of_keys.dup.each_with_object([]) do |key, deleted|
        locale, key_suffix = key.split(".", 2)
        next unless locale == "en"

        if i18n_tasks.ignore_key?(key_suffix, :missing, "es")
          deleted << list_of_keys.delete(key)
        end
      end
    end
  end
end

LocaleSyncChecker.new.run
