class ClientAgency::LaLdh::ReportFields < ClientAgency::ReportFields
  def self.caseworker_fields_for(cbv_flow)
    [
      [ ".pdf.caseworker.doc_id", ClientAgency::LaLdh::Configuration.doc_id(cbv_flow) ]
    ] + super
  end
end
