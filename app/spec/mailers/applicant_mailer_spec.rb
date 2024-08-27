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
    expect(mail.subject).to eq(I18n.t('applicant_mailer.invitation_email.subject'))
  end

  it "renders the receiver email" do
    expect(mail.to).to eq([ email ])
  end

  it "renders the sender email" do
    expect(mail.from).to eq([ "noreply@mail.localhost" ])
  end

  it "renders the body" do
    expect(mail.body.encoded).to match(I18n.t('applicant_mailer.invitation_email.body_html.default',
      agency_acronym: 'CBV',
      deadline: "July 21, 2024")
    )
  end

  context "for a NYC CbvFlowInvitation" do
    let(:cbv_flow_invitation) { create(:cbv_flow_invitation, :nyc, email_address: email) }

    it "renders the body" do
      expect(mail.body.encoded).to match(I18n.t('applicant_mailer.invitation_email.header.nyc'))
      expect(mail.body.encoded).to match(I18n.t('applicant_mailer.invitation_email.body_html.nyc',
        agency_acronym: 'HRA',
        deadline: "July 21, 2024")
      )
    end
  end

  context "for a MA CbvFlowInvitation" do
    let(:cbv_flow_invitation) { create(:cbv_flow_invitation, :ma, email_address: email) }

    it "renders the body" do
      expect(mail.body.encoded).to match(I18n.t('applicant_mailer.invitation_email.header.ma'))
      expect(mail.body.encoded).to match(I18n.t('applicant_mailer.invitation_email.body_html.default',
        agency_acronym: 'DTA',
        deadline: "July 21, 2024")
      )
    end
  end
end
