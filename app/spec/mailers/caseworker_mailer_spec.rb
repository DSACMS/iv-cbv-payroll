require "rails_helper"

RSpec.describe CaseworkerMailer, type: :mailer do
  include ViewHelper
  let(:cbv_flow) { create(:cbv_flow, :with_pinwheel_account,
    case_number: "ABC1234",
    confirmation_code: "00001",
    transmitted_at:  Date.today
  )}
  let(:caseworker_email) { cbv_flow.cbv_flow_invitation.user.email }
  let(:account_id) { cbv_flow.pinwheel_accounts.first.pinwheel_account_id }
  let(:payments) { stub_post_processed_payments(account_id) }
  let(:employments) { stub_employments(account_id) }
  let(:incomes) { stub_incomes(account_id) }
  let(:identities) { stub_identities(account_id) }
  let(:email_address) { "test@example.com" }
  let(:current_site) { SiteConfig.new(File.join(Rails.root, 'config', 'site-config.yml'))['sandbox'] }

  let(:mail) {
    CaseworkerMailer.with(
      email_address: email_address,
      cbv_flow: cbv_flow,
      payments: payments,
      employments: employments,
      incomes: incomes,
      identities: identities
    ).summary_email
  }

  describe '#summary_email' do
    before do
      cbv_flow.cbv_flow_invitation.update!(client_id_number: "123456")
    end

    it 'renders the subject with case number' do
      expect(mail.subject).to eq(I18n.t('caseworker_mailer.summary_email.subject', case_number: cbv_flow.case_number))
    end

    it 'sends to the correct email' do
      expect(mail.to).to eq([ email_address ])
    end

    it 'renders the body' do
      invitation = cbv_flow.cbv_flow_invitation
      expect(mail.body.encoded).to include("Attached is an Income Verification Report PDF with confirmation number #{cbv_flow.confirmation_code}")
      expect(mail.body.encoded).to include("confirm that their information has been submitted to CBV")
      expect(mail.body.encoded).to include("This report is associated with the case number ABC1234 and CIN #{invitation.client_id_number}")
      expect(mail.body.encoded).to include("It was requested by #{caseworker_email} on #{format_parsed_date(cbv_flow.created_at)}")
      expect(mail.body.encoded).to include("submitted by the client on #{format_parsed_date(Date.today)}")
      expect(mail.body.encoded).to include("This document is for #{current_site.agency_name} staff only")
    end

    it 'attaches a PDF which has a file name prefix of {case_number}_timestamp_' do
      expect(mail.attachments.any? { |attachment| attachment.filename =~ /\A#{cbv_flow.case_number}_\d{14}_income_verification\.pdf\z/ }).to be true
      expect(mail.attachments.first.content_type).to start_with('application/pdf')
    end
  end
end
