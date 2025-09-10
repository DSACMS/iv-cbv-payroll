class ClientAgency::PaDhs::ReportDelivererJob < ApplicationJob
  def perform(date_start, date_end)
    cbv_flows_delivered_recently = CbvFlow.where(transmitted_at: date_start..date_end).where(client_agency_id: ClientAgency::PaDhs::Configuration.client_agency_id)
    if cbv_flows_delivered_recently.empty?
      Rails.logger.info "delivered 0 applications for pa_dhs in time range #{date_start}..#{date_end}"
      return
    end

    csv = ClientAgency::PaDhs::RecentlySubmittedCasesCsv.new.generate_csv(cbv_flows_delivered_recently)

    sftp_gateway.upload_data(csv, "#{config["sftp_directory"]}/#{filename(date_start)}")

    Rails.logger.info "delivered #{cbv_flows_delivered_recently.count} applications for pa_dhs in time range #{date_start}..#{date_end}"
  end

  def sftp_gateway
    SftpGateway.new(config)
  end

  def filename(date_start)
    "#{date_start.in_time_zone("America/New_York").strftime('%Y%m%d')}_summary.csv"
  end

  def config
    ClientAgency::PaDhs::Configuration.sftp_transmission_configuration
  end
end
