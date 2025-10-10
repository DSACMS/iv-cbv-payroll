class Transmitters::SftpTransmitter
  include Transmitter

  def deliver
    config = current_agency.transmission_method_configuration.with_indifferent_access
    sftp_gateway = SftpGateway.new(config)
    filename = ClientAgency::AzDes::Configuration.pdf_filename(cbv_flow, cbv_flow.consented_to_authorized_use_at)
    sftp_gateway.upload_data(StringIO.new(pdf_output.content), "#{config["sftp_directory"]}/#{filename}.pdf")
  end

  def pdf_output
    @_pdf_output ||= begin
      pdf_service = PdfService.new(language: :en)
      pdf_service.generate(cbv_flow, aggregator_report, current_agency)
    end
  end
end
