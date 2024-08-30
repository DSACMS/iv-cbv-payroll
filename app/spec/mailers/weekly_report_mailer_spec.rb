require "rails_helper"
require 'csv'

RSpec.describe WeeklyReportMailer, type: :mailer do
  let(:now) { Time.now.in_time_zone("America/New_York") }
  let(:five_days_ago) { now - 5.days }
  let(:snap_app_date) { now.strftime("%Y-%m-%d") }
  let(:time_offset) { "#{(five_days_ago + 4.hours).strftime("%Y-%m-%d %H:%M:%S")} UTC" }
  let(:cbv_flow_invitation) { create(:cbv_flow_invitation,
    created_at: five_days_ago,
    client_id_number: "1111",
    case_number: "00001",
    site_id: 'nyc'
  )}
  let(:cbv_flow) { create(:cbv_flow, :with_pinwheel_account,
    case_number: "ABC1234",
    confirmation_code: "00001",
    created_at: five_days_ago,
    site_id: "nyc",
    transmitted_at: five_days_ago,
    cbv_flow_invitation_id: cbv_flow_invitation.id,
    consented_to_authorized_use_at: five_days_ago
  )}
  # This second flow is identical except for there is no "confirmation_code"
  # Only one entry should be part of the CSV.
  let(:cbv_flow2) { create(:cbv_flow, :with_pinwheel_account,
    case_number: "XXXXXXX",
    created_at: five_days_ago,
    site_id: "nyc",
    transmitted_at: five_days_ago,
    cbv_flow_invitation_id: cbv_flow_invitation.id,
    consented_to_authorized_use_at: five_days_ago
  )}
  let(:mail) { WeeklyReportMailer.with(cbv_flow: cbv_flow, cbv_flow_invitation: cbv_flow_invitation).report_email }
  let(:previous_week_start_date) { now.beginning_of_week - 7.days }
  let(:week_start_date) { now.beginning_of_week }
  let(:filename) { "weekly_report_#{previous_week_start_date.beginning_of_week.strftime("%Y%m%d")}-#{week_start_date.strftime("%Y%m%d")}.csv" }

  it "renders the subject" do
    expect(mail.subject).to eq("Weekly report email")
  end

  it "renders the body" do
    expect(mail.body.encoded).to include("Attached is a report from")
  end

  it "renders the csv data" do
    expect(mail.attachments.first.filename).to eq(filename)
    expect(mail.attachments.first.content_type).to start_with('text/csv')
    expect(mail.attachments.first.body.encoded.gsub(/\r/, '')).to eq(
      <<~CSV
        client_id_number,transmitted_at,case_number,created_at,snap_application_date,completed_at,site_id
        1111,#{time_offset},00001,#{time_offset},#{snap_app_date},#{time_offset},nyc
      CSV
    )
  end
end
