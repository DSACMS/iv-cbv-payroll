namespace :weekly_reports do
  desc "Send weekly reports (NYC, MA, and LA)"
  task send_all: :environment do
    report_date = Time.now.in_time_zone("America/New_York").beginning_of_week

    WeeklyReportMailer
      .with(client_agency_id: "nyc", report_date: report_date.to_date)
      .report_email
      .deliver_now

    WeeklyReportMailer
      .with(client_agency_id: "ma", report_date: report_date.to_date)
      .report_email
      .deliver_now

    WeeklyReportMailer
      .with(client_agency_id: "la_ldh", report_date: report_date.to_date)
      .report_email
      .deliver_now
  end
end
