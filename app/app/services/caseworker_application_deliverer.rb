class CaseworkerApplicationDeliverer
  attr_reader :current_agency, :cbv_flow, :aggregator_report, :start_date, :end_date

  def initialize(cbv_flow, current_agency, aggregator_report)
    @cbv_flow = cbv_flow
    @current_agency = current_agency
    @aggregator_report = aggregator_report
    @start_date = (Date.parse(aggregator_report.from_date).strftime("%b") rescue aggregator_report.from_date)
    @end_date = (Date.parse(aggregator_report.to_date).strftime("%b%Y") rescue aggregator_report.to_date)
  end

  def deliver_sftp!
    config = current_agency.transmission_method_configuration
    sftp_gateway = SftpGateway.new(config)
    sftp_gateway.upload_data(generate_csv, "#{config["sftp_directory"]}/#{filename}.csv")
    sftp_gateway.upload_data(pdf_output.content, "#{config["sftp_directory"]}/#{filename}.pdf")
  end

  def filename
    "IncomeReport_#{cbv_flow.cbv_applicant.agency_id_number}_" \
      "#{start_date}-#{end_date}_" \
      "Conf#{cbv_flow.confirmation_code}_" \
      "#{Time.now.strftime('%Y%m%d%H%M%S')}"
  end

  def pdf_output
    @_pdf_output ||= begin
                       pdf_service = PdfService.new
                       pdf_service.generate(
                         renderer: Cbv::SubmitsController.new,
                         template: "cbv/submits/show",
                         variables: {
                           is_caseworker: true,
                           cbv_flow: cbv_flow,
                           aggregator_report: aggregator_report,
                           has_consent: true
                         }
                       )
                     end
  end

  def generate_csv
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
