require "csv"
class WeeklyReportMailer < ApplicationMailer
  helper :view

  # Send email with a CSV file that reports on completed flows in past week
  def report_email
    current_site = site_config[params[:site_id]]
    raise "Invalid `site_id` parameter given: #{params[:site_id].inspect}" unless current_site.present?

    raise "Missing `report_date` param" unless params[:report_date].present?
    now = params[:report_date]

    raise "Missing `weekly_report.recipient` configuration for site: #{params[:site_id]}" unless current_site.weekly_report["recipient"]
    @recipient = current_site.weekly_report["recipient"]

    @report_range = now.prev_week.all_week
    csv_rows = weekly_report_data(current_site, @report_range)
    attachments[report_filename(@report_range)] = generate_csv(csv_rows)

    mail(
      to: @recipient,
      subject: "CBV Pilot - Weekly Report Email",
    )
  end

  private

  def report_filename(report_range)
    "weekly_report_#{report_range.begin.strftime("%Y%m%d")}-#{report_range.end.strftime("%Y%m%d")}.csv"
  end

  def weekly_report_data(current_site, report_range)
    CbvFlowInvitation
      .where(site_id: current_site.id)
      .where(created_at: report_range)
      .includes(:cbv_flows, :cbv_applicant)
      .map do |invitation|
        cbv_flow = invitation.cbv_flows.find(&:complete?)
        applicant = invitation.cbv_applicant

        base_fields = {
          invited_at: invitation.created_at,
          transmitted_at: cbv_flow&.transmitted_at,
          completed_at: cbv_flow&.consented_to_authorized_use_at,
          snap_application_date: applicant.snap_application_date,
          email_address: invitation.email_address
        }

        case current_site.id
        when "nyc"
          base_fields.merge(
            client_id_number: applicant.client_id_number,
            case_number: applicant.case_number,
          )
        when "ma"
          base_fields.merge(
            agency_id_number: applicant.agency_id_number,
            beacon_id: applicant.beacon_id
          )
        end
      end
  end

  def generate_csv(rows)
    return unless rows.any?

    CSV.generate(headers: rows.first.keys) do |csv|
      csv << rows.first.keys
      rows.each do |row|
        csv << row
      end
    end
  end
end
