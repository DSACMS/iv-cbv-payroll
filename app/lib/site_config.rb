require "yaml"

class SiteConfig
  def initialize(config_path)
    @sites = YAML.safe_load(File.read(config_path))
  end

  def site_ids
    @sites.map { |s| s["id"] }
  end
end
