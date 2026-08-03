# The Emmy App release version. `version.txt` is the single source of truth;
# see docs/versioning.md for what a MAJOR/MINOR/PATCH bump means for states.
module EmmyVersion
  VERSION_FILE = "version.txt"

  def self.current
    @current ||= begin
      Rails.root.join(VERSION_FILE).read.strip.freeze
    rescue SystemCallError, IOError
      "unknown"
    end
  end
end
