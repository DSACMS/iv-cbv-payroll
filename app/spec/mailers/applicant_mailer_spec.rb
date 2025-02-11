require "rails_helper"
require "active_support/testing/time_helpers"

RSpec.describe ApplicantMailer, type: :mailer do
  include ActiveSupport::Testing::TimeHelpers

  describe "invitation email" do
    before do
      travel_to Time.new(2024, 7, 7, 12, 0, 0, "-04:00")
    end

    after do
      travel_back
    end

    let(:email) { 'me@email.com' }
    let(:cbv_flow_invitation) { create(:cbv_flow_invitation, email_address: email) }
    let(:mail) { ApplicantMailer.with(
                  cbv_flow_invitation: cbv_flow_invitation
                ).invitation_email }

    it "renders the subject" do
      expect(mail.subject).to eq(I18n.t('applicant_mailer.invitation_email.subject.default'))
    end

    it "renders the receiver email" do
      expect(mail.to).to eq([ email ])
    end

    it "renders the sender email" do
      expect(mail.from).to eq([ "noreply@mail.localhost" ])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match(I18n.t("applicant_mailer.invitation_email.body_1.default", agency_acronym: "CBV"))
      expect(mail.body.encoded).to match(I18n.t("applicant_mailer.invitation_email.body_2_html.default", deadline: "July 21, 2024"))
    end

    context "when locale is es" do
      let(:cbv_flow_invitation) { create(:cbv_flow_invitation, language: :es) }
      it "renders the subject and body in Spanish" do
        expect(mail.subject).to eq(I18n.t('applicant_mailer.invitation_email.subject.default', locale: :es))
        expect(mail.body.encoded).to include(I18n.t("applicant_mailer.invitation_email.body_1.default", locale: :es, agency_acronym: "CBV"))
      end
    end

    context "for a NYC CbvFlowInvitation" do
      let(:cbv_flow_invitation) { create(:cbv_flow_invitation, :nyc, email_address: email) }

      it "renders the body" do
        unescaped_body = CGI.unescape_html(mail.body.encoded)
        expect(unescaped_body).to match(I18n.t('applicant_mailer.invitation_email.header.nyc'))
        expect(unescaped_body).to match(I18n.t("applicant_mailer.invitation_email.body_1.default", agency_acronym: "HRA"))
        expect(unescaped_body).to match(I18n.t("applicant_mailer.invitation_email.body_2_html.default", deadline: "July 21, 2024"))
        expect(unescaped_body).to match(I18n.t("applicant_mailer.invitation_email.body_3.default", app_name: "ACCESS HRA"))
      end
    end

    context "for a MA CbvFlowInvitation" do
      let(:cbv_flow_invitation) { create(:cbv_flow_invitation, :ma, email_address: email) }

      it "renders the subject" do
        expect(mail.subject).to eq(I18n.t('applicant_mailer.invitation_email.subject.ma'))
      end

      it "renders the body" do
        unescaped_body = CGI.unescape_html(mail.body.encoded)
        expect(unescaped_body).to match(I18n.t('applicant_mailer.invitation_email.header.ma'))
        expect(unescaped_body).to match(I18n.t("applicant_mailer.invitation_email.body_1.ma", agency_acronym: "DTA"))
        expect(unescaped_body).to match(I18n.t("applicant_mailer.invitation_email.body_2_html.ma", deadline: "July 21, 2024"))
        expect(unescaped_body).to match(I18n.t("applicant_mailer.invitation_email.body_3.ma", app_name: "DTA Connect"))
      end
    end
  end

  describe "invitation reminder email" do
    let(:now) { DateTime.now }
    let(:invitation_sent_at) { now - 5.days }
    let!(:invitation) { create(:cbv_flow_invitation, :ma, created_at: invitation_sent_at) }

    before(:each) do
      travel_to(now)
    end

    after do
      invitation.update(invitation_reminder_sent_at: nil)
      travel_back
    end

    it "sends the expected email when requirements are met" do
      expect {
        Rake::Task['invitation_reminders:send_all'].execute
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "has the correct subject line for ma" do
      invitation.update!(client_agency_id: "ma")
      Rake::Task['invitation_reminders:send_all'].execute
      email = ActionMailer::Base.deliveries.last

      expect(email.subject).to eq(I18n.t("applicant_mailer.invitation_reminder_email.subject.ma"))
    end

    it "has the correct subject line for nyc" do
      invitation.update!(client_agency_id: "nyc", case_number: "00012345678A", client_id_number: "AB00000C", snap_application_date: invitation_sent_at - 30.minutes)
      Rake::Task['invitation_reminders:send_all'].execute
      email = ActionMailer::Base.deliveries.last

      expect(email.subject).to eq(I18n.t("applicant_mailer.invitation_reminder_email.subject.nyc"))
    end

    it "does not send an email if the invitation is expired" do
      invitation.update(created_at: 15.days.ago)
      expect {
        Rake::Task['invitation_reminders:send_all'].execute
      }.not_to change { ActionMailer::Base.deliveries.count }
    end

    it "does not send an email if the invitation has already been sent" do
      invitation.update(invitation_reminder_sent_at: 1.day.ago)
      expect {
        Rake::Task['invitation_reminders:send_all'].execute
      }.not_to change { ActionMailer::Base.deliveries.count }
    end

    it "renders the body" do
      Rake::Task['invitation_reminders:send_all'].execute
      email = ActionMailer::Base.deliveries.last

      expect(email.body.encoded).to include("Log into your payroll provider account")
    end

    it "tracks events" do
      expect_any_instance_of(MixpanelEventTracker).to receive(:track)
        .with("EmailSent", anything, hash_including(
          mailer: "ApplicantMailer",
          action: "invitation_reminder_email",
          message_id: be_a(String)
        ))

      expect_any_instance_of(NewRelicEventTracker).to receive(:track)
        .with("EmailSent", anything, hash_including(
          mailer: "ApplicantMailer",
          action: "invitation_reminder_email",
          message_id: be_a(String)
        ))

      Rake::Task['invitation_reminders:send_all'].execute
    end

    context "for an invitation in Spanish" do
      before do
        invitation.update(language: "es")
      end

      it "renders the subject and body in Spanish" do
        Rake::Task['invitation_reminders:send_all'].execute
        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to eq(I18n.t('applicant_mailer.invitation_reminder_email.subject.ma', locale: :es))
      end
    end
  end
end
