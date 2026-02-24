class Transmitters::SftpTransmitter < Transmitters::BasePdfTransmitter
  TRANSMISSION_METHOD = "sftp"
  def deliver
    config = current_agency.transmission_method_configuration.with_indifferent_access
    sftp_gateway = SftpGateway.new(config)
    filename = pdf_filename(cbv_flow)
    sftp_gateway.upload_data(StringIO.new(pdf_output.content), "#{config["sftp_directory"]}/#{filename}.pdf")
  end

  private

  def pdf_filename(cbv_flow)
    [
      "CBVPilot",
      cbv_flow.consented_to_authorized_use_at.strftime("%Y%m%d"),
      "Conf#{cbv_flow.confirmation_code}"
    ].join("_")
  end
end
