class LocaleDiffService
  require 'yaml'
  require 'open3'

  BASE_BRANCH = "main"
  EN_LOCALE_PATH = "app/config/locales/en.yml"

  attr_reader :project_root

  def initialize
    @project_root = find_project_root
  end

  # Get all changed keys for a given locale file
  def get_changed_keys(locale_path)
    old_yaml_content = get_en_content_from_main
    return [] unless old_yaml_content

    old_hash = YAML.safe_load(old_yaml_content) || {}
    current_hash = load_yaml_file(File.join(@project_root, locale_path))
    return [] if current_hash.empty?

    flat_old = flatten_hash(old_hash)
    flat_current = flatten_hash(current_hash)

    find_changed_keys(flat_old, flat_current)
  end

  def find_project_root
    stdout, stderr, status = Open3.capture3("git rev-parse --show-toplevel")
    raise "Not a git repository or git not found" unless status.success?
    stdout.strip
  end

  def get_en_content_from_common_ancestor
    current_branch, stderr, status = Open3.capture3("git", "rev-parse", "--abbrev-ref", "HEAD", chdir: @project_root)
    current_branch.strip!

    unless status.success?
      puts "Error: Could not determine current branch."
      return "{}"
    end

    # Find the most recent common ancestor (merge base) between the current branch and 'main'
    merge_base_commit, stderr, status = Open3.capture3("git", "merge-base", current_branch, BASE_BRANCH, chdir: @project_root)
    merge_base_commit.strip!

    unless status.success?
      puts "Warning: Could not find common ancestor between `#{current_branch}` and `main`."
      puts "Assuming all keys are new (or 'main' is the common ancestor)."
      # Fallback to main if no common ancestor is found, or if it's the very first commit
      # This can happen if the branch was created directly off of an empty main, or if there's no shared history yet.
      return get_en_content_from_main
    end

    # Use `git show` with the common ancestor commit to get the file's content
    content, stderr, status = Open3.capture3("git", "show", "#{merge_base_commit}:#{EN_LOCALE_PATH}", chdir: @project_root)
    unless status.success?
      puts "Warning: Could not find `#{EN_LOCALE_PATH}` at common ancestor `#{merge_base_commit}`."
      puts "Assuming all keys are new."
      return "{}" # Return empty YAML if the file didn't exist at the common ancestor
    end
    content
  end

  # Uses `git show` to get the raw content of a file from a specific branch
  def get_en_content_from_main
    content, stderr, status = Open3.capture3("git", "show", "#{BASE_BRANCH}:#{EN_LOCALE_PATH}", chdir: @project_root)
    unless status.success?
      puts "Warning: Could not find `#{file_path}` on branch `#{branch}`."
      puts "Assuming all keys are new."
      return "{}" # Return empty YAML if the file doesn't exist on the base branch
    end
    content
  end

  def load_yaml_file(path)
    return {} unless File.exist?(path)
    YAML.load_file(path) || {}
  end

  # Recursively flattens a nested hash into a single-level hash with dot-separated keys
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

  # Compares the old and new flattened English hashes to find what changed
  def find_changed_keys(old_hash, new_hash)
    new_hash.keys.select do |key|
      # A key needs translation if it's new OR its value has changed.
      !old_hash.key?(key) || old_hash[key] != new_hash[key]
    end
  end
end
