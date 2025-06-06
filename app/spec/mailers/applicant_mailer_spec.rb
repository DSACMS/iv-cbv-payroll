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
  end
end
