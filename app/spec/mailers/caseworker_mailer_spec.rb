require "rails_helper"

RSpec.describe CaseworkerMailer, type: :mailer do
  let(:payments) { stub_payments }
  let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", argyle_user_id: "abc-def-ghi") }
  let(:email_address) { "test@example.com" }
  let(:mail) {
    CaseworkerMailer.with(
      email_address: email_address,
      cbv_flow: cbv_flow,
      payments: payments).summary_email.deliver_now
  }

  it 'renders the subject with case number' do
    expect(mail.subject).to eq(I18n.t('caseworker_mailer.summary_email.subject', case_number: cbv_flow.case_number))
  end

  it 'sends to the correct email' do
    expect(mail.to).to eq([ email_address ])
  end

  it 'renders the body' do
    expect(mail.body.encoded).to match(I18n.t('caseworker_mailer.summary_email.body'))
  end

  it 'attaches a PDF which has a file name prefix of {case_number}_timestamp_' do
    expect(mail.attachments.any? { |attachment| attachment.filename =~ /\A#{cbv_flow.case_number}_\d{14}_income_verification\.pdf\z/ }).to be true
    expect(mail.attachments.first.content_type).to start_with('application/pdf')
  end
end