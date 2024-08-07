require "yaml"

class SiteConfig
  def initialize(config_path)
    template = ERB.new File.read(config_path)
    @sites = YAML
      .safe_load(template.result(binding))
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
    attr_reader(*%i[
      id
      agency_name
      learn_more_link_text
      learn_more_link_url
      pay_income_days
      pinwheel_api_token
      pinwheel_environment
      transmission_method
      transmission_method_configuration
      sso
    ])

    def initialize(yaml)
      @id = yaml["id"]
      @agency_name = yaml["agency_name"]
      @pinwheel_api_token = yaml["pinwheel"]["api_token"]
      @pinwheel_environment = yaml["pinwheel"]["environment"]
      @pay_income_days = yaml["pay_income_days"]
      @learn_more_link_text = yaml["learn_more_link_text"]
      @learn_more_link_url = yaml["learn_more_link_url"]
      @transmission_method = yaml["transmission_method"]
      @transmission_method_configuration = yaml["transmission_method_configuration"]
      @sso = yaml["sso"]

      raise ArgumentError.new("Site missing id") if @id.blank?
      raise ArgumentError.new("Site #{@id} missing required attribute `agency_name`") if @agency_name.blank?
      raise ArgumentError.new("Site #{@id} missing required attribute `pinwheel.environment`") if @pinwheel_environment.blank?
      # TODO: Add a validation for the dependent attribute, transmission_method_configuration.email, if transmission_method is present
    end
  end
end
