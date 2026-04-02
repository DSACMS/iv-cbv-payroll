class Transmitters::SftpTransmitter < Transmitters::BasePdfTransmitter
  TRANSMISSION_METHOD = "sftp"
  DEFAULT_PDF_FILENAME_FORMAT = "CBVPilot_%{consent_date}_Conf%{confirmation_code}"

  def deliver
    config = current_agency.transmission_method_configuration.with_indifferent_access
    sftp_gateway = SftpGateway.new(config)
    filename = pdf_filename(cbv_flow)
    sftp_gateway.upload_data(StringIO.new(pdf_output.content), "#{config["sftp_directory"]}/#{filename}.pdf")
  end

  private

  def pdf_filename(cbv_flow)
    Transmitters::PdfFilenameFormatter.format(cbv_flow, pdf_filename_format)
  end

  def pdf_filename_format
    current_agency.transmission_method_configuration.with_indifferent_access[:pdf_filename_format].presence ||
      DEFAULT_PDF_FILENAME_FORMAT
  end
end
