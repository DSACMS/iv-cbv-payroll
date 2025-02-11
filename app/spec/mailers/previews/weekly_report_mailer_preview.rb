# Preview all emails at http://localhost:3000/rails/mailers/weekly_report_mailer_mailer
class WeeklyReportMailerPreview < ActionMailer::Preview
  def report_email
    WeeklyReportMailer.with(client_agency_id: "nyc").report_email
  end
end
