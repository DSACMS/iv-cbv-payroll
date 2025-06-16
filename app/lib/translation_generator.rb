#!/usr/bin/env ruby

# frozen_string_literal: true

require "yaml"
require "csv"
require "open3"
# require 'google/cloud/translate/v2'
require "rainbow"

# --- CONFIGURATION ---

# The branch to compare against (e.g., main, develop).
# The script will find what has changed in `en.yml` since this branch.
BASE_BRANCH = "main"

# The path to your locale files, relative to the Rails root directory.
EN_LOCALE_PATH = "app/config/locales/en.yml"
ES_LOCALE_PATH = "app/config/locales/es.yml"

# The target language for translation (e.g., 'es' for Spanish, 'fr' for French).
TARGET_LANGUAGE_CODE = "es"

# The name of the output CSV file.
OUTPUT_CSV_PATH = "translation_update.csv"

# --- SCRIPT LOGIC ---

# A helper class to encapsulate the logic for finding and translating diffs.
class TranslationDiffGenerator
  def initialize
    @project_root = find_project_root

    # @translator = Google::Cloud::Translate::V2.new

    puts Rainbow("Configuration:").bright
    puts " - Comparing against branch: #{Rainbow(BASE_BRANCH).cyan}"
    puts " - English locale: #{Rainbow(EN_LOCALE_PATH).cyan}"
    puts " - Spanish locale: #{Rainbow(ES_LOCALE_PATH).cyan}"
    puts " - Output file: #{Rainbow(OUTPUT_CSV_PATH).cyan}"
    puts "--------------------------------------------------"
  end

  # Main method to execute the script's logic.
  def generate_csv
    # 1. Get the content of the en.yml file from the base branch.
    puts "1. Fetching old `en.yml` from `#{BASE_BRANCH}` branch..."
    old_en_yaml_content = get_file_content_from_git(BASE_BRANCH, EN_LOCALE_PATH)
    return unless old_en_yaml_content

    old_en_hash = YAML.safe_load(old_en_yaml_content) || {}

    # 2. Load the current locale files.
    puts "2. Loading current locale files from your branch..."
    current_en_hash = load_yaml_file(File.join(@project_root, EN_LOCALE_PATH))
    current_es_hash = load_yaml_file(File.join(@project_root, ES_LOCALE_PATH))

    # 3. Flatten the hashes to make them easy to compare (e.g., { "en.users.show.title" => "User Profile" }).
    flat_old_en = flatten_hash(old_en_hash)
    flat_current_en = flatten_hash(current_en_hash)
    flat_current_es = flatten_hash(current_es_hash)

    # 4. Find all keys that are new or have a different value in the current en.yml.
    puts "3. Comparing versions to find new or modified strings..."
    keys_to_translate = find_changed_keys(flat_old_en, flat_current_en)

    if keys_to_translate.empty?
      puts Rainbow("✅ No new or modified English keys found. You're all set!").green
      return
    end

    puts Rainbow("Found #{keys_to_translate.count} keys that are new or modified.").yellow

    # 5. Generate the CSV file with translations.
    puts "4. Translating strings to `#{TARGET_LANGUAGE_CODE}` and generating CSV..."
    create_csv(keys_to_translate, flat_current_en)

    puts Rainbow("\n🎉 Success! CSV file created at: #{OUTPUT_CSV_PATH}").green
    puts "Please review the file and send it to your translation service."
  # rescue Google::Cloud::Error => e
  #   puts Rainbow("\n💥 Google Cloud Error:").red
  #   puts Rainbow("   Could not authenticate or communicate with the Translation API.").red
  #   puts Rainbow("   Please ensure you have run `export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json`").red
  #   puts "   Error details: #{e.message}"
  rescue StandardError => e
    puts Rainbow("\n💥 An unexpected error occurred:").red
    puts e.message
    puts e.backtrace
  end

  private

  # Finds the git project root directory.
  def find_project_root
    stdout, stderr, status = Open3.capture3("git rev-parse --show-toplevel")
    raise "Not a git repository or git not found" unless status.success?
    stdout.strip
  end

  # Uses `git show` to get the raw content of a file from a specific branch.
  def get_file_content_from_git(branch, file_path)
    git_path = "#{branch}:#{file_path}"
    content, stderr, status = Open3.capture3("git", "show", git_path, chdir: @project_root)
    unless status.success?
      puts Rainbow("Warning: Could not find `#{file_path}` on branch `#{branch}`.").yellow
      puts "Assuming all keys are new."
      return "{}" # Return empty YAML if the file doesn't exist on the base branch
    end
    content
  end

  # Loads and parses a YAML file from the filesystem.
  def load_yaml_file(path)
    return {} unless File.exist?(path)
    YAML.load_file(path) || {}
  end

  # Recursively flattens a nested hash into a single-level hash with dot-separated keys.
  # Example: { "en" => { "hello" => "Hello" } } becomes { "en.hello" => "Hello" }
  def flatten_hash(hash, prefix = [])
    hash.each_with_object({}) do |(key, value), result|
      current_prefix = prefix + [ key ]
      if value.is_a?(Hash)
        result.merge!(flatten_hash(value, current_prefix))
      else
        result[current_prefix.join(".")] = value
      end
    end
  end

  # Compares the old and new flattened English hashes to find what changed.
  def find_changed_keys(old_en, new_en)
    new_en.keys.select do |key|
      # A key needs translation if it's new OR its value has changed.
      !old_en.key?(key) || old_en[key] != new_en[key]
    end
  end

  # Creates the final CSV file.
  def create_csv(keys, english_strings)
    # Using a progress bar for user feedback during translation
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

        # begin
        #   translated_text = @translator.translate(english_text, to: TARGET_LANGUAGE_CODE).text
        # rescue => e
        #   puts Rainbow("Warning: Could not translate '#{english_text}'. Error: #{e.message}").yellow
        #   translated_text = "TRANSLATION_FAILED"
        # end

        csv << [ key_for_csv, english_text ]

        # Update and print the progress bar
        progress = (index + 1).to_f / total_keys
        filled_length = (progress * progress_bar_length).to_i
        bar = "█" * filled_length + "-" * (progress_bar_length - filled_length)
        print "\rProgress: [#{Rainbow(bar).green}] #{(progress * 100).to_i}%"
      end
    end
  end
end

# --- EXECUTION ---

# This block runs only when the script is executed directly from the command line.
if __FILE__ == $0
  TranslationDiffGenerator.new.generate_csv
end
