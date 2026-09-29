require "yaml"
require "uri"

class ClientAgencyConfig
  attr_reader :api

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
  VALID_APPLICATION_REPORTING_MONTHS = [ 1, 2, 3 ]
  VALID_RENEWAL_REQUIRED_MONTHS = 1..6
  VALID_REDACTION_TYPES = %w[string date email object uuid]
  DOCUMENT_CONTENT_TYPES = {
    "pdf" => "application/pdf",
    "png" => "image/png",
    "jpeg" => "image/jpeg",
    "bmp" => "image/bmp",
    "tiff" => "image/tiff"
  }.freeze
  DEFAULT_ALLOWED_DOCUMENT_TYPES = DOCUMENT_CONTENT_TYPES.keys.freeze
  DEFAULT_MAX_DOCUMENT_UPLOAD_SIZE_MB = 40
  # Keep this at or below the upload-processing Lambda ceiling in emmy-infra.
  MAX_DOCUMENT_UPLOAD_SIZE_MB = 40

  ACTIVITY_TRANSMISSION_URL_KEYS = {
    "http" => "documents_api_url",
    "json" => "json_api_url"
  }.freeze

  def initialize(config_path)
    template = ERB.new File.read(config_path)
    @client_agencies = YAML
      .safe_load(template.result(binding), aliases: true)
      .map { |s| [ s["id"], ClientAgency.new(s) ] }
      .to_h
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
      agency_missing_employers_website
      agency_domain
      authorized_emails
      caseworker_fallback_email
      caseworker_feedback_form
      default_origin
      invitation_valid_days
      logo_path
      logo_square_path
      pay_income_days
      application_reporting_months
      renewal_required_months
      pinwheel_api_token
      pinwheel_environment
      pilot_ended
      argyle_environment
      staff_portal_enabled
      sso
      income_flow_transmission_method
      activity_flow_transmission_method
      income_transmission_method_configuration
      activity_transmission_method_configuration
      weekly_report
      applicant_attributes
      generic_links_disabled
      activity_types
      allowed_iframe_ancestors
      allowed_document_types
      max_document_upload_size_mb
    ])

    def initialize(yaml)
      @id = yaml["id"]
      @agency_name = yaml["agency_name"]
      @agency_contact_website = yaml["agency_contact_website"]
      # Special override for nh_dhhs; verify whether this can be removed if
      # that pilot config is removed:
      @agency_missing_employers_website = yaml["agency_missing_employers_website"]
      @agency_domain = yaml["agency_domain"]
      @api = yaml["api"] || {}
      @authorized_emails = yaml["authorized_emails"] || ""
      @caseworker_feedback_form = yaml["caseworker_feedback_form"]
      @default_origin = yaml["default_origin"]
      @invitation_valid_days = yaml["invitation_valid_days"]
      @logo_path = yaml["logo_path"]
      @logo_square_path = yaml["logo_square_path"]
      @pay_income_days = yaml.fetch("pay_income_days", { w2: 90, gig: 90 }).symbolize_keys
      @application_reporting_months = yaml["application_reporting_months"] || 1
      @renewal_required_months = yaml["renewal_required_months"]
      @pinwheel_environment = yaml["pinwheel"]["environment"] || "sandbox"
      @pilot_ended = yaml["pilot_ended"] || false
      @argyle_environment = yaml["argyle"]["environment"] || "sandbox"
      @income_flow_transmission_method = yaml["income_flow_transmission_method"]
      @activity_flow_transmission_method = yaml["activity_flow_transmission_method"]
      @income_transmission_method_configuration = yaml["income_transmission_method_configuration"]
      @activity_transmission_method_configuration = yaml["activity_transmission_method_configuration"]
      @staff_portal_enabled = yaml["staff_portal_enabled"]
      @sso = yaml["sso"]
      @weekly_report = yaml["weekly_report"]
      @generic_links_disabled = yaml["generic_links_disabled"]
      @activity_types = yaml["activity_types"]&.symbolize_keys || {}
      @caseworker_fallback_email = yaml["caseworker_fallback_email"]
      @allowed_iframe_ancestors = yaml["allowed_iframe_ancestors"] || []
      @allowed_document_types = yaml.fetch("allowed_document_types", DEFAULT_ALLOWED_DOCUMENT_TYPES)
      @max_document_upload_size_mb = yaml.fetch("max_document_upload_size_mb", DEFAULT_MAX_DOCUMENT_UPLOAD_SIZE_MB)

      # Normalize applicant attributes to ensure both v1 and v2 keys exist
      # and that both versions have the same set of attributes
      raw_applicant_attributes = yaml["applicant_attributes"] || {}
      @applicant_attributes =
        if raw_applicant_attributes.key?("v1") || raw_applicant_attributes.key?("v2")
          raw_applicant_attributes
        else
          { "v1" => raw_applicant_attributes, "v2" => raw_applicant_attributes }
        end

      # Normalize applicant attributes to ensure both v1 and v2 keys exist
      # and that both versions have the same set of attributes
      raw_applicant_attributes = yaml["applicant_attributes"] || {}
      @applicant_attributes =
        if raw_applicant_attributes.key?("v1") || raw_applicant_attributes.key?("v2")
          raw_applicant_attributes
        else
          { "v1" => raw_applicant_attributes, "v2" => raw_applicant_attributes }
        end

      raise ArgumentError.new("Client Agency missing id") if @id.blank?
      raise ArgumentError.new("Client Agency #{@id} `allowed_iframe_ancestors` must be a list") unless @allowed_iframe_ancestors.is_a?(Array)
      raise ArgumentError.new("Client Agency #{@id} missing required attribute `agency_name`") if @agency_name.blank?
      unsupported_document_types = @allowed_document_types - DOCUMENT_CONTENT_TYPES.keys
      if @allowed_document_types.empty? || unsupported_document_types.any?
        raise ArgumentError.new("Client Agency #{@id} invalid value for allowed_document_types")
      end
      unless @max_document_upload_size_mb.between?(1, MAX_DOCUMENT_UPLOAD_SIZE_MB)
        raise ArgumentError.new("Client Agency #{@id} invalid value for max_document_upload_size_mb")
      end
      raise ArgumentError.new("Client Agency #{@id} invalid value for pay_income_days.w2") unless VALID_PAY_INCOME_DAYS.include?(@pay_income_days[:w2])
      raise ArgumentError.new("Client Agency #{@id} invalid value for pay_income_days.gig") unless VALID_PAY_INCOME_DAYS.include?(@pay_income_days[:gig])
      raise ArgumentError.new("Client Agency #{@id} invalid value for application_reporting_months") unless VALID_APPLICATION_REPORTING_MONTHS.include?(@application_reporting_months)
      raise ArgumentError.new("Client Agency #{@id} invalid value for renewal_required_months") unless @renewal_required_months.blank? || VALID_RENEWAL_REQUIRED_MONTHS.include?(@renewal_required_months)
      raise ArgumentError.new("Client Agency #{@id} missing required attribute `income_flow_transmission_method`") if @income_flow_transmission_method.blank?

      validate_activity_transmission_configuration!

      @applicant_attributes.each_value do |attrs|
        attrs.each do |name, options|
          redaction_type = options.is_a?(Hash) ? options["redaction_type"] : nil
          next if redaction_type.nil?
          unless VALID_REDACTION_TYPES.include?(redaction_type)
            raise ArgumentError.new("Client Agency #{@id} applicant attribute `#{name}` has an invalid `redaction_type`: "\
              "#{redaction_type.inspect}. Valid types: #{VALID_REDACTION_TYPES}")
          end
        end
      end
    end

    def applicant_attributes(version: :v1)
      # Silently fallback to v1 if the requested version is not available
      @applicant_attributes.fetch(version.to_s) { @applicant_attributes.fetch("v1", {}) }
    end

    def applicant_attribute_names(version: :v1)
      applicant_attributes(version: version).compact.keys.map(&:to_sym)
    end

    def redactable_applicant_fields(version: :v1)
      applicant_attributes(version: version).each_with_object({}) do |(name, options), fields|
        next unless options.is_a?(Hash) && options["redaction_type"]
        fields[name.to_sym] = options["redaction_type"].to_sym
      end
    end

    def allowed_document_content_types
      @allowed_document_types.map { |type| DOCUMENT_CONTENT_TYPES.fetch(type) }
    end

    def max_document_upload_size_bytes
      @max_document_upload_size_mb.megabytes
    end

    def api_metadata(flow_type, version: :v2)
      @api
        .dig(version.to_s, flow_type.to_s, "metadata")
        .to_a
        .map(&:to_sym)
    end

    def api_required_metadata(flow_type, version: :v2)
      @api
        .dig(version.to_s, flow_type.to_s, "required")
        .to_a
        .map(&:to_sym)
    end

    private

    def validate_activity_transmission_configuration!
      has_method = @activity_flow_transmission_method.present?
      has_configuration = @activity_transmission_method_configuration.present?

      if has_method && !has_configuration
        raise ArgumentError.new("Client Agency #{@id} sets `activity_flow_transmission_method` but is missing `activity_transmission_method_configuration`")
      end

      if has_configuration && !has_method
        raise ArgumentError.new("Client Agency #{@id} sets `activity_transmission_method_configuration` but is missing `activity_flow_transmission_method`")
      end

      return unless has_method

      config_key = ACTIVITY_TRANSMISSION_URL_KEYS[@activity_flow_transmission_method]
      return if config_key.nil?

      url = @activity_transmission_method_configuration[config_key]
      return if absolute_http_url?(url)

      raise ArgumentError.new("Client Agency #{@id} `#{config_key}` must be an absolute HTTP(S) URL, got #{url.inspect}")
    end

    def absolute_http_url?(url)
      return false if url.blank?

      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      false
    end
  end
end
