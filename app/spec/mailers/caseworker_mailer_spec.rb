require "rails_helper"
require 'action_view' # Include this to use the `strip_tags` helper

RSpec.describe CaseworkerMailer, type: :mailer do
  include ViewHelper
  include ActionView::Helpers::SanitizeHelper # Include the sanitize helper

  let(:cbv_flow) { create(:cbv_flow, :with_pinwheel_account,
    case_number: "ABC1234",
    confirmation_code: "00001",
    site_id: "nyc",
    consented_to_authorized_use_at: Time.now
  )}
  let(:caseworker_email) { cbv_flow.cbv_flow_invitation.user.email }
  let(:account_id) { cbv_flow.pinwheel_accounts.first.pinwheel_account_id }
  let(:payments) { stub_post_processed_payments(account_id) }
  let(:employments) { stub_employments(account_id) }
  let(:incomes) { stub_incomes(account_id) }
  let(:identities) { stub_identities(account_id) }
  let(:email_address) { "test@example.com" }
  let(:current_site) { SiteConfig.new(File.join(Rails.root, 'config', 'site-config.yml'))[cbv_flow.site_id] }

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

      # Access the HTML part of the email and strip HTML tags
      email_html = mail.html_part.body.decoded
      email_body = strip_tags(email_html).gsub(/\s+/, ' ').strip
      expected_date = format_parsed_date(Time.zone.today)
      request_date = format_parsed_date(cbv_flow.created_at)
      expect(email_body).to include("Attached is an Income Verification Report PDF with confirmation number #{cbv_flow.confirmation_code}")
      expect(email_body).to include("confirm that their information has been submitted to HRA")
      expect(email_body).to include("This report is associated with the case number ABC1234 and CIN #{invitation.client_id_number}")
      expect(email_body).to include("It was requested by #{caseworker_email} on #{request_date}")
      expect(email_body).to include("submitted by the client on #{expected_date}")
    end

    it 'attaches a PDF which has a file name prefix of {case_number}_timestamp_' do
      expect(mail.attachments.any? { |attachment| attachment.filename =~ /\A#{cbv_flow.case_number}_\d{14}_income_verification\.pdf\z/ }).to be true
      expect(mail.attachments.first.content_type).to start_with('application/pdf')
    end
  end
end
