require "csv"
class WeeklyReportMailer < ApplicationMailer
  helper :view

  # Send email with a CSV file that reports on completed flows in past week
  def report_email
    current_agency = client_agency_config[params[:client_agency_id]]
    raise "Invalid `client_agency_id` parameter given: #{params[:client_agency_id].inspect}" unless current_agency.present?

    raise "Missing `report_date` param" unless params[:report_date].present?
    now = params[:report_date]

    raise "Missing `weekly_report.recipient` configuration for client agency: #{params[:client_agency_id]}" unless current_agency.weekly_report["recipient"]
    @recipient = current_agency.weekly_report["recipient"]

    @report_range = now.prev_week.all_week
    csv_rows = weekly_report_data(current_agency, @report_range)
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

  def weekly_report_data(current_agency, report_range)
    CbvFlowInvitation
      .where(client_agency_id: current_agency.id)
      .where(created_at: report_range)
      .includes(:cbv_flows)
      .map do |invitation|
        cbv_flow = invitation.cbv_flows.find(&:complete?)

        base_fields = {
          invited_at: invitation.created_at,
          transmitted_at: cbv_flow&.transmitted_at,
          completed_at: cbv_flow&.consented_to_authorized_use_at,
          snap_application_date: invitation.snap_application_date,
          email_address: invitation.email_address
        }

        case current_agency.id
        when "nyc"
          base_fields.merge(
            client_id_number: invitation.client_id_number,
            case_number: invitation.case_number,
          )
        when "ma"
          base_fields.merge(
            agency_id_number: invitation.agency_id_number,
            beacon_id: invitation.beacon_id
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
