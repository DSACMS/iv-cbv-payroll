class AzDesConfiguration
  def self.sftp_transmission_configuration
    Rails.application.config.client_agencies["az_des"].transmission_method_configuration
  end

  def self.client_agency_id
    "az_des"
  end

  def self.pdf_filename(cbv_flow, time)
    "CBVPilot_#{cbv_flow.cbv_applicant.case_number}_" \
      "#{time.strftime('%Y%m%d')}_" \
      "Conf#{cbv_flow.confirmation_code}"
  end
end
