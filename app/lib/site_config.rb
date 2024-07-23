require "yaml"

class SiteConfig
  def initialize(config_path)
    @sites = YAML
      .safe_load(File.read(config_path))
      .map { |s| [ s["id"], Site.new(s) ] }
      .to_h
  end

  def site_ids
    @sites.keys
  end

  def [](site_id)
    @sites[site_id]
  end

  class Site
    attr_reader :id, :agency_name

    def initialize(yaml)
      @id = yaml["id"]
      @agency_name = yaml["agency_name"]

      raise ArgumentError.new("Site missing id") if @id.blank?
      raise ArgumentError.new("Site #{@id} missing required attribute `agency_name`") if @agency_name.blank?
    end
  end
end
