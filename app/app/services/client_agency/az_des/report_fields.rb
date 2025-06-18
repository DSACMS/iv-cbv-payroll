class ClientAgency::AzDes::ReportFields
  def self.caseworker_fields_for(cbv_flow)
    [
      [ ".pdf.caseworker.case_number", ClientAgency::AzDes::Configuration.case_number(cbv_flow) ],
      [ ".pdf.caseworker.other_jobs", cbv_flow.has_other_jobs ]
    ]
  end
end
