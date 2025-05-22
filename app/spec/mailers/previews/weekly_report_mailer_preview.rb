# Preview all emails at http://localhost:3000/rails/mailers/weekly_report_mailer
class WeeklyReportMailerPreview < ActionMailer::Preview
  def report_email_la_ldh
    WeeklyReportMailer.with(
      client_agency_id: "la_ldh",
      report_date: Date.today
    ).report_email
  end
end
