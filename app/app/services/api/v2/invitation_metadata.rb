class Api::V2::InvitationMetadata
  def initialize(params:, client_agency_id:, flow_type:)
    @params = params
    @client_agency_id = client_agency_id
    @flow_type = flow_type
  end

  def permitted
    @params
      .fetch(:agency_partner_metadata, {})
      .permit(*metadata_fields)
  end

  def errors
    missing_required_fields.map do |field|
      {
        field: field,
        message_key: "api.v2.fields.#{field}.blank"
      }
    end + agency_metadata_errors
  end

  private

  attr_reader :client_agency_id, :flow_type

  def agency
    Rails.application.config.client_agencies[client_agency_id.to_s] ||
      raise(KeyError, "No client agency config for #{client_agency_id.inspect}")
  end

  def agency_metadata_errors
    klass = "CbvApplicant::#{client_agency_id.to_s.camelize}".constantize
    klass.api_v2_metadata_errors(flow_type, permitted)
  end

  def metadata_fields
    agency.api_metadata(flow_type, :v2)
  end

  def required_fields
    agency.api_required_metadata(flow_type, :v2)
  end

  def missing_required_fields
    required_fields.filter_map do |field|
      field unless permitted[field].present?
    end
  end
end
