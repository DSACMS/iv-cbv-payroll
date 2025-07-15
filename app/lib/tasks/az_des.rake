namespace :az_des do
  desc "create API production user"
  task create_api_access_token: :environment do
    user = User.find_or_create_by(
      email: "ffs-eng+az_des@navapbc.com",
      client_agency_id: "az_des"
    )

    user.update(is_service_account: true)
    access_token = user.api_access_tokens.first || user.api_access_tokens.create

    puts "User #{user.id} (#{user.email}) created, with API access token: #{access_token.access_token}"
  end

  desc "deliver csv summary of cases sent to az_des"
  task deliver_csv_reports: :environment do
    time_zone = "America/Phoenix"
    now = Time.find_zone(time_zone).now
    start_time = now.yesterday.change(hour: 8)
    end_time = now.change(hour: 8)
    ClientAgency::AzDes::ReportDelivererJob.perform_later(start_time, end_time)
  end

  desc "backfill agency name matches"
  task backfill_agency_name_matches: :environment do
    puts "Backfilling agency name matches:"
    CbvFlow
      .completed
      .unredacted
      .where(client_agency_id: "az_des")
      .find_each do |cbv_flow|
      puts "  CbvFlow id = #{cbv_flow.id}"
      MatchAgencyNamesJob.perform_now(cbv_flow.id)
    end
  end
end
