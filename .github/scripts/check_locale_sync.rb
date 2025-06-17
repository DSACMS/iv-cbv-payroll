require 'yaml'
require 'open3'

# For GitHub Actions, we need to load the service differently since it's not in a Rails app
# Try to load from the Rails app structure first, fall back to inline definition
begin
  require_relative '../../app/services/locale_diff_service'
rescue LoadError
  # Inline service definition for GitHub Actions
  require 'yaml'
  require 'open3'

  class LocaleDiffService
    def initialize(base_branch = 'main')
      @base_branch = base_branch
      @project_root = find_project_root
    end

    def get_changed_keys(locale_path)
      old_yaml_content = get_file_content_from_git(@base_branch, locale_path)
      return [] unless old_yaml_content

      old_hash = YAML.safe_load(old_yaml_content) || {}
      current_hash = load_yaml_file(File.join(@project_root, locale_path))
      return [] if current_hash.empty?

      flat_old = flatten_hash(old_hash)
      flat_current = flatten_hash(current_hash)

      find_changed_keys(flat_old, flat_current)
    end

    private

    def find_project_root
      stdout, stderr, status = Open3.capture3("git rev-parse --show-toplevel")
      raise "Not a git repository or git not found" unless status.success?
      stdout.strip
    end

    def get_file_content_from_git(branch, file_path)
      git_path = "#{branch}:#{file_path}"
      content, stderr, status = Open3.capture3("git", "show", git_path, chdir: @project_root)
      unless status.success?
        puts "Warning: Could not find `#{file_path}` on branch `#{branch}`."
        puts "Assuming all keys are new."
        return "{}"
      end
      content
    end

    def load_yaml_file(path)
      return {} unless File.exist?(path)
      YAML.load_file(path) || {}
    end

    def flatten_hash(hash, prefix = [])
      hash.each_with_object({}) do |(key, value), result|
        current_prefix = prefix + [key]
        if value.is_a?(Hash)
          result.merge!(flatten_hash(value, current_prefix))
        else
          result[current_prefix.join(".")] = value
        end
      end
    end

    def find_changed_keys(old_hash, new_hash)
      new_hash.keys.select do |key|
        !old_hash.key?(key) || old_hash[key] != new_hash[key]
      end
    end
  end
end

class LocaleSyncChecker
  def initialize
    @base_branch = ENV['GITHUB_BASE_REF'] || 'main'
    @en_locale_path = 'app/config/locales/en.yml'
    @es_locale_path = 'app/config/locales/es.yml'
    @locale_diff_service = LocaleDiffService.new(@base_branch)
  end

  def run
    puts "Checking locale synchronization against #{@base_branch}"

    en_changed_keys = @locale_diff_service.get_changed_keys(@en_locale_path)
    es_changed_keys = @locale_diff_service.get_changed_keys(@es_locale_path)

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
