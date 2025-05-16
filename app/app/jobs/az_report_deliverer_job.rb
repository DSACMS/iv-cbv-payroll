class AzReportDelivererJob < ApplicationJob
  def perform(date_start, date_end)
    cbv_applicants_delivered_recently = CbvFlow.where(transmitted_at: date_start..date_end).where(client_agency_id: AzDesConfiguration.client_agency_id)
    if cbv_applicants_delivered_recently.empty?
      Rails.logger.info "delivered 0 applications for az_des today"
      return
    end

    csv = AzDesRecentlySubmittedCasesCsv.new.generate_csv(cbv_applicants_delivered_recently)

    sftp_gateway.upload_data(csv, "#{config["sftp_directory"]}/#{filename(date_start)}.pdf")

    Rails.logger.info "delivered #{cbv_applicants_delivered_recently.count} applications for az_des today"
  end

  def sftp_gateway
    SftpGateway.new(config)
  end

  def filename(date_start)
    "#{date_start.strftime('%Y%m%d')}_summary.csv"
  end

  def config
    AzDesConfiguration.sftp_transmission_configuration
  end
end
