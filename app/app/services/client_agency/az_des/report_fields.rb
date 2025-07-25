class ClientAgency::AzDes::ReportFields < ClientAgency::ReportFields
  def self.caseworker_fields_for(cbv_flow)
    [
      [ ".pdf.caseworker.case_number", ClientAgency::AzDes::Configuration.case_number(cbv_flow) ]
    ] + super
  end
end
