namespace :pa_dhs do
  desc "create API production user"
  task create_api_access_token: :environment do
    user = User.find_or_create_by(
      email: "ffs-eng+pa_dhs@digitalpublicworks.org",
      client_agency_id: "pa_dhs"
    )

    user.update(is_service_account: true)
    access_token = user.api_access_tokens.first || user.api_access_tokens.create

    puts "User #{user.id} (#{user.email}) created, with API access token: #{access_token.access_token}"
  end

  desc "deliver csv summary of cases sent to pa_dhs"
  task deliver_csv_reports: :environment do
    config = ClientAgency::PaDhs::Configuration.sftp_transmission_configuration
    unless config.fetch("csv_summary_reports_enabled", true)
      puts "PA DHS CSV summary delivery disabled, not enqueuing job"
      next
    end

    time_zone = "America/New_York"
    now = Time.find_zone(time_zone).now
    start_time = now.yesterday.change(hour: 8)
    end_time = now.change(hour: 8)
    ClientAgency::PaDhs::ReportDelivererJob.perform_later(start_time, end_time)
  end

  desc "backfill agency name matches"
  task backfill_agency_name_matches: :environment do
    puts "Backfilling agency name matches:"
    CbvFlow
      .completed
      .unredacted
      .where(client_agency_id: "pa_dhs")
      .find_each do |cbv_flow|
      puts "  CbvFlow id = #{cbv_flow.id}"
      MatchAgencyNamesJob.perform_now(cbv_flow.id)
    end
  end
end
