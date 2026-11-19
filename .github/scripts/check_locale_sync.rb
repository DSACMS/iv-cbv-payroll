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

    en_changed_keys_raw = en_changed_keys.map { |key| remove_language_prefix(key) }
    es_changed_keys_raw = es_changed_keys.map { |key| remove_language_prefix(key) }

    puts "\n=== Synchronization Status ==="
    missing_in_spanish = en_changed_keys_raw - es_changed_keys_raw
    
    # Spanish changes are allowed without English changes, as long as the English key exists.
    extra_in_spanish = es_changed_keys_raw - en_changed_keys_raw
    invalid_spanish_changes = extra_in_spanish.reject { |key| english_key_exists?(key) }

    if missing_in_spanish.empty? && invalid_spanish_changes.empty?
      puts "\n✅ SUCCESS: English and Spanish locales are synchronized!"
      exit 0
    else
      puts "\n❌ FAILURE: English and Spanish locales are not synchronized!"
      print_synchronization_issues(missing_in_spanish, invalid_spanish_changes)
      exit 1
    end
  end

  private

  def english_key_exists?(key)
    @en_flat_current ||= begin
      _, flat = @locale_diff_service.get_changed_keys_in_this_branch("en")
      flat
    end
    @en_flat_current.key?("en.#{key}")
  end

  def remove_language_prefix(key)
    key.sub(/^(en|es)\./, '')
  end

  def print_synchronization_issues(missing_in_spanish, invalid_spanish_changes)
    puts "\n=== Synchronization Issues ==="

    unless missing_in_spanish.empty?
      puts "\n🔸 Keys changed in English but not in Spanish:"
      missing_in_spanish.each { |key| puts "  - #{key}" }
    end

    unless invalid_spanish_changes.empty?
      puts "\n🔸 Keys changed in Spanish that do not exist in English:"
      invalid_spanish_changes.each { |key| puts "  - #{key}" }
    end

    puts "\n💡 To fix this:"
    puts "   - Ensure that any changes to English locale keys are also reflected in Spanish."
    puts "   - Ensure that any new Spanish keys have a corresponding English key."
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
