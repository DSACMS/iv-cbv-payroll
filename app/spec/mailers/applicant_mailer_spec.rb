require "rails_helper"

RSpec.describe ApplicantMailer, type: :mailer do
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

  describe 'send_pdf_to_caseworker' do
    let(:email_address) { 'caseworker@example.com' }
    let(:case_number) { '123ABC' }
    let(:mail) { ApplicantMailer.send_pdf_to_caseworker(email_address, case_number) }

    it 'renders the subject with case number' do
      expect(mail.subject).to eq(I18n.t('applicant_mailer.send_pdf_to_caseworker.subject', case_number: case_number))
    end

    it 'sends to the correct email' do
      expect(mail.to).to eq([email_address])
    end

    it 'attaches a PDF' do
      expect(mail.attachments['income_verification.pdf']).to be_present
      expect(mail.attachments['income_verification.pdf'].content_type).to start_with('application/pdf')
    end
  end
end