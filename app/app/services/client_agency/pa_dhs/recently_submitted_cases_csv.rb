class ClientAgency::PaDhs::RecentlySubmittedCasesCsv < CsvGenerator
  def generate_csv(cbv_flows)
    data = cbv_flows.map do |cbv_flow|
      invitation = cbv_flow.cbv_flow_invitation

      {
        case_number: cbv_flow.cbv_applicant.case_number,
        confirmation_code: cbv_flow.confirmation_code,
        cbv_link_created_timestamp: invitation ? ClientAgency::PaDhs::Configuration.format_timezone(cbv_flow.cbv_flow_invitation.created_at) : nil,
        cbv_link_clicked_timestamp: ClientAgency::PaDhs::Configuration.format_timezone(cbv_flow.created_at),
        report_created_timestamp: ClientAgency::PaDhs::Configuration.format_timezone(cbv_flow.consented_to_authorized_use_at),
        consent_timestamp: ClientAgency::PaDhs::Configuration.format_timezone(cbv_flow.consented_to_authorized_use_at),
        pdf_filename: "#{ClientAgency::PaDhs::Configuration.pdf_filename(cbv_flow, cbv_flow.consented_to_authorized_use_at)}.pdf",
        pdf_filetype: "application/pdf",
        language: invitation&.language
      }
    end


    CsvGenerator.create_csv_multiple_datapoints(data)
  end
end
