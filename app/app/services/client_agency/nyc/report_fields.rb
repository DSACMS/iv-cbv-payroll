class ClientAgency::Nyc::ReportFields
  def self.caseworker_fields_for(cbv_flow)
    [
      [ ".pdf.caseworker.client_id_number", cbv_flow.cbv_applicant.client_id_number ],
      [ ".pdf.caseworker.case_number", cbv_flow.cbv_applicant.case_number ],
      [ ".pdf.caseworker.other_jobs", cbv_flow.has_other_jobs ]
    ]
  end
end
