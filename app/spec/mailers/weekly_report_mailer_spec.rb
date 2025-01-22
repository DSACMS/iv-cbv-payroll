require "rails_helper"
require 'csv'

RSpec.describe WeeklyReportMailer, type: :mailer do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { DateTime.new(2024, 9, 9, 9, 0, 0, "-04:00") }
  let(:site_id) { "nyc" }
  let(:invitation_sent_at) { now - 5.days }
  let(:snap_app_date) { now.strftime("%Y-%m-%d") }
  let(:cbv_flow_invitation) do
    create(:cbv_flow_invitation,
           site_id.to_sym,
           created_at: invitation_sent_at,
           snap_application_date: invitation_sent_at - 1.day,
          )
  end
  let(:cbv_flow) do
    create(
      :cbv_flow, :with_pinwheel_account,
      case_number: cbv_flow_invitation.case_number,
      confirmation_code: "00001",
      created_at: invitation_sent_at + 15.minutes,
      site_id: site_id,
      transmitted_at: invitation_sent_at + 30.minutes,
      cbv_flow_invitation_id: cbv_flow_invitation.id,
      consented_to_authorized_use_at: invitation_sent_at + 30.minutes
    )
  end
  let(:mail) do
    WeeklyReportMailer
      .with(report_date: now, site_id: cbv_flow.site_id)
      .report_email
  end
  let(:previous_week_start_date) { now.beginning_of_week - 7.days }
  let(:week_start_date) { now.beginning_of_week }
  let(:parsed_csv) do
    CSV.parse(mail.attachments.first.body.encoded, headers: :first_row).map(&:to_h)
  end

  before do
    travel_to(now)
  end

  it "renders the subject" do
    expect(mail.subject).to eq("CBV Pilot - Weekly Report Email")
  end

  it "renders the body" do
    expect(mail.body.encoded).to include("Attached is a report from")
  end

  it "tracks events" do
    expect_any_instance_of(MixpanelEventTracker).to receive(:track)
      .with("EmailSent", anything, hash_including(
        mailer: "WeeklyReportMailer",
        action: "report_email",
        message_id: be_a(String)
      ))

    expect_any_instance_of(NewRelicEventTracker).to receive(:track)
      .with("EmailSent", anything, hash_including(
        mailer: "WeeklyReportMailer",
        action: "report_email",
        message_id: be_a(String)
      ))

    mail.deliver_now
  end

  it "renders the csv data from the week before the report_date" do
    expect(mail.attachments.first.filename).to eq("weekly_report_20240902-20240908.csv")
    expect(mail.attachments.first.content_type).to start_with('text/csv')

    expect(parsed_csv[0]).to match(
      "client_id_number" => cbv_flow_invitation.client_id_number,
      "transmitted_at" => "2024-09-04 13:30:00 UTC",
      "case_number" => cbv_flow.case_number,
      "invited_at" => "2024-09-04 13:00:00 UTC",
      "snap_application_date" => "2024-09-03",
      "completed_at" => "2024-09-04 13:30:00 UTC",
      "email_address" => "test@example.com"
    )
    expect(parsed_csv.length).to eq(1)
  end

  context "when the invitation was sent before the week of the report" do
    let(:invitation_sent_at) { now.prev_week.beginning_of_week - 1.minute }

    it "excludes the record from the CSV" do
      expect(parsed_csv.length).to eq(0)
      expect(parsed_csv).not_to include(hash_including(
        "client_id_number" => cbv_flow_invitation.client_id_number
      ))
    end
  end

  context "when there are is an incomplete CbvFlow" do
    let!(:incomplete_invitation) do
      create(:cbv_flow_invitation,
             :nyc,
             created_at: invitation_sent_at,
            )
    end
    let!(:incomplete_flow) do
      create(:cbv_flow, :with_pinwheel_account,
             created_at: invitation_sent_at,
             site_id: site_id,
             cbv_flow_invitation: incomplete_invitation
            )
    end

    it "includes them in the CSV data" do
      expect(parsed_csv.length).to eq(2)
      expect(parsed_csv).to include(hash_including(
        "client_id_number" => incomplete_invitation.client_id_number,
        "transmitted_at" => nil,
        "case_number" => incomplete_invitation.case_number,
        "invited_at" => "2024-09-04 13:00:00 UTC",
        "snap_application_date" => match(/\d\d\d\d-\d\d-\d\d/),
        "completed_at" => nil,
        "email_address" => "test@example.com"
      ))
    end
  end

  context "for the MA site" do
    let(:site_id) { "ma" }

    it "renders the CSV data with MA-specific columns" do
      expect(mail.attachments.first.filename).to eq("weekly_report_20240902-20240908.csv")
      expect(mail.attachments.first.content_type).to start_with('text/csv')

      expect(parsed_csv[0]).to match(
        "beacon_id" => cbv_flow_invitation.beacon_id,
        "transmitted_at" => "2024-09-04 13:30:00 UTC",
        "agency_id_number" => cbv_flow_invitation.agency_id_number,
        "invited_at" => "2024-09-04 13:00:00 UTC",
        "snap_application_date" => "2024-09-03",
        "completed_at" => "2024-09-04 13:30:00 UTC",
        "email_address" => "test@example.com"
      )
      expect(parsed_csv.length).to eq(1)
    end
  end
end
