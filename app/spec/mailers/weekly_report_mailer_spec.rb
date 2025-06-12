require "rails_helper"
require 'csv'

RSpec.describe WeeklyReportMailer, type: :mailer do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { DateTime.new(2024, 9, 9, 9, 0, 0, "-04:00") }
  let(:invitation_sent_at) { now - 5.days }
  let(:client_agency_id) { "la_ldh" }
  let(:cbv_flow_invitation) { nil }
  let(:cbv_flow) do
    create(
      :cbv_flow, :with_pinwheel_account,
      confirmation_code: "00001",
      created_at: invitation_sent_at + 15.minutes,
      client_agency_id: client_agency_id,
      transmitted_at: invitation_sent_at + 30.minutes,
      cbv_flow_invitation: cbv_flow_invitation,
      consented_to_authorized_use_at: invitation_sent_at + 30.minutes
    )
  end
  let(:mail) do
    cbv_flow
    WeeklyReportMailer
      .with(report_date: now, client_agency_id: client_agency_id)
      .report_email
  end
  let(:parsed_csv) do
    CSV.parse(mail.attachments.first.body.encoded, headers: :first_row).map(&:to_h)
  end

  before do
    travel_to(now)
  end

  after do
    travel_back
  end

  it "renders the subject" do
    expect(mail.subject).to eq("CBV Pilot - Weekly Report Email")
  end

  it "renders the body" do
    expect(mail.body.encoded).to include("Attached is a report from")
  end

  it "tracks events" do
    expect(EventTrackingJob).to receive(:perform_later).with("EmailSent", anything, hash_including(
        mailer: "WeeklyReportMailer",
        action: "report_email",
        message_id: be_a(String)
      ))

    mail.deliver_now
  end

  it "includes complete flows in the CSV data" do
    expect(parsed_csv.length).to eq(1)
    expect(parsed_csv[0]).to include(
      "started_at" => "2024-09-04 13:15:00 UTC",
      "completed_at" => "2024-09-04 13:30:00 UTC"
    )
  end

  it "excludes data from outside the report week" do
    create(:cbv_flow, :with_pinwheel_account,
           confirmation_code: "00002",
           created_at: now.prev_week.beginning_of_week - 1.minute,
           transmitted_at: now.prev_week.beginning_of_week,
           consented_to_authorized_use_at: now.prev_week.beginning_of_week,
           client_agency_id: client_agency_id)

    expect(parsed_csv.length).to eq(1)
  end

  it "raises error for unknown report variant" do
    fake_agency = double(
      id: "fake_agency",
      weekly_report: { "report_variant" => "unknown_variant" }
    )
    report_range = now.prev_week.all_week

    expect {
      described_class.new.send(:weekly_report_data, fake_agency, report_range)
    }.to raise_error("Unknown report variant: unknown_variant")
  end

  context "for generic flows" do
    it "excludes incomplete flows from the CSV data" do
      create(:cbv_flow, :invited,
             created_at: invitation_sent_at,
             client_agency_id: client_agency_id)

      expect(parsed_csv.length).to eq(1)
    end

    context "LA LDH" do
      it "renders the CSV data with LA-specific columns" do
        expect(mail.attachments.first.filename).to eq("weekly_report_20240902-20240908.csv")
        expect(mail.attachments.first.content_type).to start_with('text/csv')

        expect(parsed_csv[0]).to match(
          "case_number" => cbv_flow.cbv_applicant.case_number,
          "started_at" => "2024-09-04 13:15:00 UTC",
          "transmitted_at" => "2024-09-04 13:30:00 UTC",
          "completed_at" => "2024-09-04 13:30:00 UTC"
        )
        expect(parsed_csv.length).to eq(1)
      end
    end
  end

  context "for invitation flows" do
    let(:client_agency_id) { "az_des" }
    let(:cbv_flow_invitation) { create(:cbv_flow_invitation, :az_des, created_at: invitation_sent_at) }

    before do
      az_config = double(
        id: "az_des",
        weekly_report: {
          "recipient" => "test@azdes.gov",
          "report_variant" => "invitations"
        }
      )
      allow_any_instance_of(WeeklyReportMailer).to receive(:client_agency_config).and_return({
        "az_des" => az_config
      })
    end

    it "includes incomplete flows" do
      incomplete_invitation = create(:cbv_flow_invitation, :az_des, created_at: invitation_sent_at)
      create(:cbv_flow, :invited, :with_pinwheel_account,
             created_at: invitation_sent_at,
             client_agency_id: client_agency_id,
             cbv_flow_invitation: incomplete_invitation)

      expect(parsed_csv.length).to eq(2)
      incomplete_record = parsed_csv.find { |row| row["completed_at"].blank? }
      expect(incomplete_record).to be_present
    end

    it "includes unused invitations" do
      create(:cbv_flow_invitation, :az_des, created_at: invitation_sent_at)

      expect(parsed_csv.length).to eq(2)
      unused_record = parsed_csv.find { |row| row["started_at"].blank? }
      expect(unused_record).to be_present
    end

    it "includes multiple flows from the same invitation" do
      create(:cbv_flow, :with_pinwheel_account,
             confirmation_code: "00003",
             created_at: invitation_sent_at + 1.hour,
             transmitted_at: invitation_sent_at + 1.hour + 15.minutes,
             consented_to_authorized_use_at: invitation_sent_at + 1.hour + 15.minutes,
             client_agency_id: client_agency_id,
             cbv_flow_invitation: cbv_flow_invitation)

      expect(parsed_csv.length).to eq(2)

      flows = parsed_csv.sort_by { |row| row["started_at"] }
      expect(flows[0]["invited_at"]).to eq("2024-09-04 13:00:00 UTC")
      expect(flows[1]["invited_at"]).to eq("2024-09-04 13:00:00 UTC")
      expect(flows[0]["started_at"]).to eq("2024-09-04 13:15:00 UTC")
      expect(flows[1]["started_at"]).to eq("2024-09-04 14:00:00 UTC")
    end

    context "AZ DES" do
      it "renders the CSV data with AZ-specific columns" do
        expect(parsed_csv[0]).to match(
          "case_number" => cbv_flow.cbv_applicant.case_number,
          "started_at" => "2024-09-04 13:15:00 UTC",
          "transmitted_at" => "2024-09-04 13:30:00 UTC",
          "completed_at" => "2024-09-04 13:30:00 UTC",
          "email_address" => "test@example.com",
          "invited_at" => "2024-09-04 13:00:00 UTC"
        )
        expect(parsed_csv.length).to eq(1)
      end
    end
  end
end
