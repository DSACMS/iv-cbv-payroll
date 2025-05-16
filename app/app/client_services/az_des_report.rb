class AzDesReport < CsvGenerator
  def generate_csv(cbv_flows)
    data = cbv_flows.map do |cbv_flow|
      {
        case_number: cbv_flow.cbv_applicant.case_number,
        confirmation_code: cbv_flow.confirmation_code,
        cbv_link_created_timestamp: cbv_flow.cbv_flow_invitation.created_at.strftime("%m/%d/%Y :%H:%M:%S"),
        cbv_link_clicked_timestamp: cbv_flow.created_at.strftime("%m/%d/%Y :%H:%M:%S"),
        report_created_timestamp: cbv_flow.consented_to_authorized_use_at.strftime("%m/%d/%Y :%H:%M:%S"),
        report_date_start: cbv_flow.cbv_applicant.paystubs_query_begins_at.strftime("%m/%d/%Y"),
        report_date_end: cbv_flow.cbv_applicant.snap_application_date.strftime("%m/%d/%Y"),
        consent_timestamp: cbv_flow.consented_to_authorized_use_at.strftime("%m/%d/%Y %H:%M:%S"),
        pdf_filename: "#{AzDesConfiguration.pdf_filename(cbv_flow, cbv_flow.transmitted_at)}.pdf",
        pdf_filetype: "application/pdf",
        language: cbv_flow.cbv_flow_invitation.language
      }
    end


    CsvGenerator.create_csv_multiple_datapoints(data)
  end
end
