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
      agency_short_name
      agency_contact_website
      caseworker_feedback_form
      invitation_valid_days
      logo_path
      logo_square_path
      pay_income_days
      pinwheel_api_token
      pinwheel_environment
      sso
      transmission_method
      transmission_method_configuration
    ])

    def initialize(yaml)
      @id = yaml["id"]
      @agency_name = yaml["agency_name"]
      @agency_short_name = yaml["agency_short_name"]
      @agency_contact_website = yaml["agency_contact_website"]
      @caseworker_feedback_form = yaml["caseworker_feedback_form"]
      @invitation_valid_days = yaml["invitation_valid_days"]
      @logo_path = yaml["logo_path"]
      @logo_square_path = yaml["logo_square_path"]
      @pay_income_days = yaml["pay_income_days"]
      @pinwheel_api_token = yaml["pinwheel"]["api_token"]
      @pinwheel_environment = yaml["pinwheel"]["environment"]
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
