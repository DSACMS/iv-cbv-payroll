class CaseworkerApplicationDeliverer
  attr_reader :current_agency, :cbv_flow, :aggregator_report

  def initialize(cbv_flow, current_agency, aggregator_report)
    @cbv_flow = cbv_flow
    @current_agency = current_agency
    @aggregator_report = aggregator_report
  end

  def deliver_sftp!
    config = current_agency.transmission_method_configuration
    sftp_gateway = SftpGateway.new(config)
    transmitted_time = Time.now
    filename = AzDesConfiguration.pdf_filename(cbv_flow, transmitted_time)
    sftp_gateway.upload_data(pdf_output.content, "#{config["sftp_directory"]}/#{filename}.pdf")
    cbv_flow.update!(transmitted_at: transmitted_time)
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
end
