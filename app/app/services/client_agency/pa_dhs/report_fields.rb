class ClientAgency::PaDhs::ReportFields < ClientAgency::ReportFields
  def self.caseworker_fields_for(cbv_flow)
    [
      [ ".pdf.caseworker.case_number", ClientAgency::PaDhs::Configuration.case_number(cbv_flow) ]
    ] + super
  end
end
