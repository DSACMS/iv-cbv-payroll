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
        message_key: "cbv.applicant_informations.#{client_agency_id}.fields.#{field}.blank"
      }
    end + agency_metadata_errors
  end

  private

  attr_reader :client_agency_id, :flow_type

  def agency
    agency_id = client_agency_id.to_s
    Rails.application.config.x.client_agencies_v2[agency_id] ||
      raise(KeyError, "No V2 configuration for client agency #{agency_id.inspect}")
  end

  def agency_metadata_errors
    klass = "CbvApplicant::#{client_agency_id.to_s.camelize}".constantize
    klass.api_v2_metadata_errors(flow_type, permitted)
  end

  def metadata_fields
    agency.api_metadata(flow_type)
  end

  def required_fields
    agency.api_required_metadata(flow_type)
  end

  def missing_required_fields
    required_fields.filter_map do |field|
      field unless permitted[field].present?
    end
  end
end
