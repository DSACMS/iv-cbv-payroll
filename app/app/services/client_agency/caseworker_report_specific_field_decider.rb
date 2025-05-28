class ClientAgency::CaseworkerReportSpecificFieldDecider
  def self.caseworker_specific_fields(cbv_flow)
    report_field_klass = agency_class(cbv_flow)
    return [] if report_field_klass.nil?
    report_field_klass.fields_for(cbv_flow)
  end

  def self.agency_class(cbv_flow)
    "ClientAgency::#{cbv_flow.client_agency_id.camelize}::ReportFields".safe_constantize
  end
end
