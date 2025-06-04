class ClientAgency::AzDes::Configuration
  def self.sftp_transmission_configuration
    Rails.application.config.client_agencies["az_des"]
      .transmission_method_configuration
      .with_indifferent_access
  end

  def self.client_agency_id
    "az_des"
  end

  def self.pdf_filename(cbv_flow, time)
    time = time.in_time_zone("America/Phoenix")
    "CBVPilot_#{case_number(cbv_flow)}_" \
      "#{time.strftime('%Y%m%d')}_" \
      "Conf#{cbv_flow.confirmation_code}"
  end

  def self.case_number(cbv_flow)
    cbv_flow.cbv_applicant.case_number.rjust(8, "0")
  end

  def self.format_timezone(time)
    return nil if time.nil?

    time.in_time_zone("America/Phoenix").strftime("%m/%d/%Y %H:%M:%S")
  end

  def self.format_date(time)
    return nil if time.nil?

    time.in_time_zone("America/Phoenix").strftime("%m/%d/%Y")
  end
end
