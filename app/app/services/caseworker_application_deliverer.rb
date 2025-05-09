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
    report_instance = report_class.new
    sftp_gateway.upload_data(report_instance.generate_csv(cbv_flow, pdf_output, filename), "#{config["sftp_directory"]}/#{filename}.csv")
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

  def report_class
    "#{current_agency.id}_report".camelize.constantize
  end
end
