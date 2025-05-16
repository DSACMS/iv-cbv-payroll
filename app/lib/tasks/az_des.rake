namespace :az_des do
  desc "deliver csv summary of cases sent to az_des"
  task :deliver_csv_reports do
    time_zone = "America/Phoenix"
    now = Time.find_zone(time_zone).now
    start_time = now.yesterday.change(hour: 8)
    end_time = now.change(hour: 8)
    AzReportDelivererJob.perform_later(start_time, end_time)
  end
end
