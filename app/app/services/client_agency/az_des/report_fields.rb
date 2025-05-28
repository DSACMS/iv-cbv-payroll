class ClientAgency::AzDes::ReportFields
  def self.fields_for(cbv_flow)
    [
      [ ".pdf.caseworker.case_number", ClientAgency::AzDes::Configuration.case_number(cbv_flow) ]
    ]
  end
end
