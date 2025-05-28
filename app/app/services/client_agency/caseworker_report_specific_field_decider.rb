class ClientAgency::CaseworkerReportSpecificFieldDecider
  def self.caseworker_specific_fields(cbv_flow)
    report_field_klass = agency_class(cbv_flow)
    return [] if report_field_klass.nil?
    return [] unless report_field_klass.respond_to?(:caseworker_fields_for)
    report_field_klass.caseworker_fields_for(cbv_flow)
  end

  def self.applicant_specific_fields(cbv_flow)
    report_field_klass = agency_class(cbv_flow)
    return [] if report_field_klass.nil?
    return [] unless report_field_klass.respond_to?(:applicant_fields_for)
    report_field_klass.applicant_fields_for(cbv_flow)
  end

  def self.agency_class(cbv_flow)
    "ClientAgency::#{cbv_flow.client_agency_id.camelize}::ReportFields".safe_constantize
  end
end
