require "rails_helper"

RSpec.describe ApplicantMailer, type: :mailer do
  let(:payments) do
    5.times.map do |i|
      {
        employer: "Employer #{i + 1}",
        amount: (100 * (i + 1)),
        start: Date.today.beginning_of_month + i.months,
        end: Date.today.end_of_month + i.months,
        hours: (40 * (i + 1)),
        rate: (10 + i)
      }
    end
  end

  let(:email) { 'me@email.com' }
  let(:link) { 'www.google.com' }
  let(:mail) { ApplicantMailer.with(email_address: email, link: link).invitation_email }

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
    expect(mail.body.encoded).to match(I18n.t('applicant_mailer.invitation_email.body'))
  end

  describe 'caseworker_summary_email' do
    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", argyle_user_id: "abc-def-ghi") }
    let(:email_address) { ENV["SLACK_TEST_EMAIL"] }
    let(:mail) {
      ApplicantMailer.with(
        email_address: email_address,
        cbv_flow: cbv_flow,
        payments: payments).caseworker_summary_email.deliver_now
    }

    it 'renders the subject with case number' do
      expect(mail.subject).to eq(I18n.t('applicant_mailer.caseworker_summary_email.subject', case_number: cbv_flow.case_number))
    end

    it 'sends to the correct email' do
      expect(mail.to).to eq([ email_address ])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match(I18n.t('applicant_mailer.caseworker_summary_email.body'))
    end

    it 'attaches a PDF' do
      expect(mail.attachments['income_verification.pdf']).to be_present
      expect(mail.attachments['income_verification.pdf'].content_type).to start_with('application/pdf')
    end
  end
end
