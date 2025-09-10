require "rails_helper"
require 'action_view' # Include this to use the `strip_tags` helper

RSpec.describe CaseworkerMailer, type: :mailer do
  include ReportViewHelper
  include ActionView::Helpers::SanitizeHelper # Include the sanitize helper

  let(:cbv_flow) { create(:cbv_flow,
    :invited,
    :with_pinwheel_account,
    confirmation_code: "00001",
    client_agency_id: "sandbox",
    consented_to_authorized_use_at: Time.now,
    cbv_applicant_attributes: {
      case_number: "ABC1234"
    }
  )}
  let(:caseworker_email) { cbv_flow.cbv_flow_invitation.user.email }
  let(:pinwheel_report) { build(:pinwheel_report, :with_pinwheel_account) }
  let(:email_address) { "test@example.com" }
  # TODO: test to make sure that it loads the correct agency for this test
  let(:current_agency) { ClientAgencyConfig.new(File.join(Rails.root, 'config', 'client-agency-config', "#{cbv_flow.client_agency_id}.yml"), true) }

  let(:mail) {
    CaseworkerMailer.with(
      email_address: email_address,
      cbv_flow: cbv_flow,
      aggregator_report: pinwheel_report,
    ).summary_email
  }

  describe '#summary_email' do
    before do
      cbv_flow.cbv_applicant.update!(client_id_number: "123456")
    end

    context 'subject line' do
      context 'with default agency' do
        it 'includes the case number' do
          expect(mail.subject).to eq("Income Verification Report #{cbv_flow.cbv_applicant.case_number} has been received")
        end
      end

      context 'with la_ldh agency' do
        before do
          cbv_flow.update!(client_agency_id: "la_ldh")
        end

        it 'uses the custom format with confirmation code' do
          expect(mail.subject).to eq("CBV Report #{cbv_flow.confirmation_code}")
        end
      end
    end

    it 'sends to the correct email' do
      expect(mail.to).to eq([ email_address ])
    end

    it 'renders the body' do
      applicant = cbv_flow.cbv_applicant

      # Access the HTML part of the email and strip HTML tags
      email_html = mail.html_part.body.decoded
      email_body = strip_tags(email_html).gsub(/\s+/, ' ').strip
      expected_date = format_parsed_date(Time.zone.today)
      request_date = format_parsed_date(cbv_flow.created_at)
      expect(email_body).to include("Attached is a Report My Income CBV Report PDF with confirmation number #{cbv_flow.confirmation_code}")
    end

    it 'attaches a PDF which has a file name prefix of {case_number}_timestamp_' do
      expect(mail.attachments.any? { |attachment| attachment.filename =~ /\A#{cbv_flow.cbv_applicant.case_number}_\d{14}_income_verification\.pdf\z/ }).to be true
      expect(mail.attachments.first.content_type).to start_with('application/pdf')
    end
  end
end
