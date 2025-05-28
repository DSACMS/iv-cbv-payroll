class ClientAgency::Ma::ReportFields
  def self.caseworker_fields_for(cbv_flow)
    [
      [ ".pdf.caseworker.client_email_address", cbv_flow.cbv_flow_invitation.email_address ],
      [ ".pdf.caseworker.snap_agency_id", cbv_flow.cbv_applicant.agency_id_number ]
    ]
  end

  def self.applicant_fields_for(cbv_flow)
    [
      [ ".pdf.client.agency_id_number", cbv_flow.cbv_applicant.agency_id_number ]
    ]
  end
end
