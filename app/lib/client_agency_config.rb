require "yaml"

class ClientAgencyConfig
  # These are the only supported number of days we allow an agency to define in
  # the `pay_income_days` configuration option.
  #
  # Every value in this array must have a corresponding partial webhook
  # subscription in ArgyleWebhooksManager in order to properly allow the user
  # to continue as soon as that amount of data has synced.
  #
  # If you add a new entry to this list, also search for
  # 'ninety_days'/'six_months' to see other places you will need to customize.
  VALID_PAY_INCOME_DAYS = [ 90, 182 ]

  # load all configuration files in the configuration directory passed in if load_all_agency_configs is true,
  # otherwise load configurations where the environment variable for 'active' is set to true
  def initialize(config_path, load_all_agency_configs)
    @client_agencies = Dir.glob(File.join(config_path, "*.yml"))
     .each_with_object({}) do |path, h|
      data = load_yaml(path)
      # load all in dev, otherwise load only if the 'active' property is true for the env (see agency config file)
      next unless load_all_agency_configs || ActiveModel::Type::Boolean.new.cast(data["active"])

      puts "LOADED AGENCY #{data["id"]}"
      id = data["id"]
      h[id] = ClientAgency.new(data)
    end
  end

  def load_yaml(path)
    template = ERB.new(File.read(path))
    YAML.safe_load(template.result(binding))
  end

  def self.client_agencies
    Rails.application.config.client_agencies
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
      agency_contact_website
      agency_domain
      authorized_emails
      caseworker_feedback_form
      default_origin
      invitation_valid_days
      logo_path
      logo_square_path
      pay_income_days
      pinwheel_api_token
      pinwheel_environment
      pilot_ended
      argyle_environment
      staff_portal_enabled
      sso
      transmission_method
      transmission_method_configuration
      weekly_report
      applicant_attributes
      allow_invitation_reuse
      generic_links_disabled
      report_customization_show_earnings_list
    ])

    def initialize(yaml)
      @id = yaml["id"]
      @agency_name = yaml["agency_name"]
      @agency_contact_website = yaml["agency_contact_website"]
      @agency_domain = yaml["agency_domain"]
      @authorized_emails = yaml["authorized_emails"] || ""
      @caseworker_feedback_form = yaml["caseworker_feedback_form"]
      @default_origin = yaml["default_origin"]
      @invitation_valid_days = yaml["invitation_valid_days"]
      @logo_path = yaml["logo_path"]
      @logo_square_path = yaml["logo_square_path"]
      @pay_income_days = yaml.fetch("pay_income_days", { w2: 90, gig: 90 }).symbolize_keys
      @pinwheel_environment = yaml["pinwheel"]["environment"] || "sandbox"
      @pilot_ended = yaml["pilot_ended"] || false
      @argyle_environment = yaml["argyle"]["environment"] || "sandbox"
      @transmission_method = yaml["transmission_method"]
      @transmission_method_configuration = yaml["transmission_method_configuration"]
      @staff_portal_enabled = yaml["staff_portal_enabled"]
      @sso = yaml["sso"]
      @weekly_report = yaml["weekly_report"]
      @applicant_attributes = yaml["applicant_attributes"] || {}
      @allow_invitation_reuse = yaml["allow_invitation_reuse"] || false
      @report_customization_show_earnings_list = yaml["report_customization_show_earnings_list"] || false
      @generic_links_disabled = yaml["generic_links_disabled"]
      @report_customizations = yaml["report_customizations"] || {}

      raise ArgumentError.new("Client Agency missing id") if @id.blank?
      raise ArgumentError.new("Client Agency #{@id} missing required attribute `agency_name`") if @agency_name.blank?
      raise ArgumentError.new("Client Agency #{@id} invalid value for pay_income_days.w2") unless VALID_PAY_INCOME_DAYS.include?(@pay_income_days[:w2])
      raise ArgumentError.new("Client Agency #{@id} invalid value for pay_income_days.gig") unless VALID_PAY_INCOME_DAYS.include?(@pay_income_days[:gig])
      raise ArgumentError.new("Client Agency #{@id} missing required attribute `transmission_method`") if @transmission_method.blank?
    end
  end
end
