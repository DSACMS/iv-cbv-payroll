require "yaml"

class ClientAgencyConfig
  def initialize(config_path)
    template = ERB.new File.read(config_path)
    @client_agencies = YAML
      .safe_load(template.result(binding))
      .map { |s| [ s["id"], ClientAgency.new(s) ] }
      .to_h
  end

  def client_agency_ids
    @client_agencies.keys
  end

  def [](client_agency_id)
    @client_agencies[client_agency_id]
  end

  class ClientAgency
    attr_reader(*%i[
      id
      agency_name
      agency_short_name
      agency_contact_website
      authorized_emails
      caseworker_feedback_form
      invitation_valid_days
      logo_path
      logo_square_path
      pay_income_days
      pinwheel_api_token
      pinwheel_environment
      argyle_environment
      staff_portal_enabled
      sso
      transmission_method
      transmission_method_configuration
      weekly_report
      applicant_attributes
    ])

    def initialize(yaml)
      @id = yaml["id"]
      @agency_name = yaml["agency_name"]
      @agency_short_name = yaml["agency_short_name"]
      @agency_contact_website = yaml["agency_contact_website"]
      @authorized_emails = yaml["authorized_emails"] || ""
      @caseworker_feedback_form = yaml["caseworker_feedback_form"]
      @invitation_valid_days = yaml["invitation_valid_days"]
      @logo_path = yaml["logo_path"]
      @logo_square_path = yaml["logo_square_path"]
      @pay_income_days = yaml["pay_income_days"]
      @pinwheel_environment = yaml["pinwheel"]["environment"] || "sandbox"
      @argyle_environment = yaml["argyle"]["environment"] || "sandbox"
      @transmission_method = yaml["transmission_method"]
      @transmission_method_configuration = yaml["transmission_method_configuration"]
      @staff_portal_enabled = yaml["staff_portal_enabled"]
      @sso = yaml["sso"]
      @weekly_report = yaml["weekly_report"]
      @applicant_attributes = yaml["applicant_attributes"] || {}

      raise ArgumentError.new("Client Agency missing id") if @id.blank?
      raise ArgumentError.new("Client Agency #{@id} missing required attribute `agency_name`") if @agency_name.blank?
      raise ArgumentError.new("Client Agency #{@id} missing required attribute `pinwheel.environment`") if @pinwheel_environment.blank?
      # TODO: Add a validation for the dependent attribute, transmission_method_configuration.email, if transmission_method is present
    end
  end
end
