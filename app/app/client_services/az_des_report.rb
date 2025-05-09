class AzDesReport < CsvGenerator
  def generate_csv(cbv_flow, pdf_output, filename)
    payroll_account = PayrollAccount.find_by(cbv_flow_id: cbv_flow.id)

    data = {
      client_id: cbv_flow.cbv_applicant.agency_id_number,
      first_name: cbv_flow.cbv_applicant.first_name,
      last_name: cbv_flow.cbv_applicant.last_name,
      middle_name: cbv_flow.cbv_applicant.middle_name,
      client_email_address: cbv_flow.cbv_flow_invitation.email_address,
      beacon_userid: cbv_flow.cbv_applicant.beacon_id,
      app_date: cbv_flow.cbv_applicant.snap_application_date.strftime("%m/%d/%Y"),
      report_date_created: payroll_account.created_at.strftime("%m/%d/%Y"),
      report_date_start: cbv_flow.cbv_applicant.paystubs_query_begins_at.strftime("%m/%d/%Y"),
      report_date_end: cbv_flow.cbv_applicant.snap_application_date.strftime("%m/%d/%Y"),
      confirmation_code: cbv_flow.confirmation_code,
      consent_timestamp: cbv_flow.consented_to_authorized_use_at.strftime("%m/%d/%Y %H:%M:%S"),
      pdf_filename: "#{filename}.pdf",
      pdf_filetype: "application/pdf",
      pdf_filesize: pdf_output.file_size,
      pdf_number_of_pages: pdf_output.page_count
    }

    CsvGenerator.create_csv(data)
  end
end
