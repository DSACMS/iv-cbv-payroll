class ClientAgency::AzDes::RecentlySubmittedCasesCsv < CsvGenerator
  def generate_csv(cbv_flows)
    begin
      data = cbv_flows.map do |cbv_flow|
        {
          case_number: cbv_flow.cbv_applicant.case_number,
          confirmation_code: cbv_flow.confirmation_code,
          cbv_link_created_timestamp: ClientAgency::AzDes::Configuration.format_timezone(cbv_flow.cbv_flow_invitation.created_at),
          cbv_link_clicked_timestamp: ClientAgency::AzDes::Configuration.format_timezone(cbv_flow.created_at),
          report_created_timestamp: ClientAgency::AzDes::Configuration.format_timezone(cbv_flow.consented_to_authorized_use_at),
          consent_timestamp: ClientAgency::AzDes::Configuration.format_timezone(cbv_flow.consented_to_authorized_use_at),
          pdf_filename: "#{ClientAgency::AzDes::Configuration.pdf_filename(cbv_flow, cbv_flow.consented_to_authorized_use_at)}.pdf",
          pdf_filetype: "application/pdf",
          language: cbv_flow.cbv_flow_invitation.language
        }
      end
    rescue NoMethodError => e
      Rails.logger.error("Error generating csv. CbvFlow ID: #{cbv_flow.id}. Error: #{e.message}")
    end

    CsvGenerator.create_csv_multiple_datapoints(data)
  end
end
