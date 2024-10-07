namespace :weekly_reports do
  desc "Send weekly reports (NYC and later others?)"
  task send_all: :environment do
    report_date = Time.now.in_time_zone("America/New_York").beginning_of_week

    WeeklyReportMailer
      .with(site_id: "nyc", report_date: report_date.to_date)
      .report_email
      .deliver_now
  end
end
