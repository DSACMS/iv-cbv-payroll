require "csv"
class WeeklyReportMailer < ApplicationMailer
  helper_method :week_start_date_formatted, :prev_week_start_date_formatted

  # Send email with a CSV file that reports on completed flows in past week
  def report_email
    email_address = site_config["nyc"].transmission_method_configuration["email"]
    site_id = "nyc"
    now = Time.now
    previous_week_start_date = now.beginning_of_week.prev_week
    week_start_date = now.beginning_of_week
    filename = "weekly_report_#{previous_week_start_date.beginning_of_week.strftime("%Y%m%d")}-#{week_start_date.strftime("%Y%m%d")}.csv"
    # Get flows from start of previous week to today
    csv_rows = weekly_report_data(site_id, previous_week_start_date, week_start_date)
    # The column "consented_to_authorized_use_at" should be reported as "completed_at"
    attachments[filename] = generate_csv(csv_rows)
    mail(
      to: email_address,
      subject: "Weekly report email",
    )
  end

  private

  def weekly_report_data(site_id, previous_week_start_date, week_start_date)
    CbvFlowInvitation
      .where(site_id: site_id)
      .where(created_at: previous_week_start_date..week_start_date)
      .map do |invitation|
        cbv_flow = invitation.cbv_flows.complete.first
        {
          "client_id_number" => invitation.client_id_number,
          "transmitted_at" => cbv_flow&.transmitted_at,
          "case_number" => invitation.case_number,
          "created_at" => invitation.created_at,
          "snap_application_date" => invitation.snap_application_date,
          "completed_at" => cbv_flow&.consented_to_authorized_use_at,
          "site_id" => invitation.site_id
        }
      end
  end

  def generate_csv(rows)
    rows.count > 0 &&
    CSV.generate(headers: rows.first.keys) do |csv|
      csv << rows.first.keys
      rows.each do |row|
        csv << row
      end
    end
  end

  def week_start_date_formatted
    Time.now.beginning_of_week.strftime("%A, %B %d, %Y")
  end

  def prev_week_start_date_formatted
    previous_week_start = Time.now.beginning_of_week - 7.days
    previous_week_start.strftime("%A, %B %d, %Y")
  end
end
