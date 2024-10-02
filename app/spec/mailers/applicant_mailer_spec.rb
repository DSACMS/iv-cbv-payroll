require "rails_helper"
require "active_support/testing/time_helpers"

RSpec.describe ApplicantMailer, type: :mailer do
  include ActiveSupport::Testing::TimeHelpers

  before do
    travel_to Time.new(2024, 7, 7, 12, 0, 0, "-04:00")
  end

  after do
    travel_back
  end

  let(:email) { 'me@email.com' }
  let(:cbv_flow_invitation) { create(:cbv_flow_invitation, email_address: email) }
  let(:mail) { ApplicantMailer.with(cbv_flow_invitation: cbv_flow_invitation).invitation_email }

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
      expect(mail.body.encoded).to match(I18n.t("applicant_mailer.invitation_email.body_1.default", locale: :es, agency_acronym: "CBV"))
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
