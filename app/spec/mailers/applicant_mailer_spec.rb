require "rails_helper"
require "active_support/testing/time_helpers"

RSpec.describe ApplicantMailer, type: :mailer do
  include ActiveSupport::Testing::TimeHelpers

  before do
    travel_to Time.new(2024, 7, 7)
  end

  after do
    travel_back
  end

  let(:email) { 'me@email.com' }
  let(:cbv_flow_invitation) { CbvFlowInvitation.create(email_address: email, site_id: 'nyc') }
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
    expect(mail.body.encoded).to match(I18n.t('applicant_mailer.invitation_email.body_html',
      agency_acronym: 'HRA',
      deadline: "July 21, 2024")
    )
  end
end
