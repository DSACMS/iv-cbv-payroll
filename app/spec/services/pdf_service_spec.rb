require 'rails_helper'

RSpec.describe PdfService, type: :service do
  describe '#generate_pdf' do
    include PinwheelApiHelper
    include Cbv::ReportsHelper

    let(:caseworker_user) { create(:user, email: "#{SecureRandom.uuid}@example.com") }
    let(:invitation) { create(:cbv_flow_invitation, :nyc, user: caseworker_user) }
    let(:cbv_flow) do
      create(
        :cbv_flow,
        :with_pinwheel_account,
        consented_to_authorized_use_at: Time.now,
        cbv_flow_invitation: invitation
      )
    end
    let(:account_id) { cbv_flow.pinwheel_accounts.first.pinwheel_account_id }
    let(:payments) { stub_post_processed_payments(account_id) }
    let(:employments) { stub_employments(account_id) }
    let(:incomes) { stub_incomes(account_id) }
    let(:identities) { stub_identities(account_id) }
    let(:payments_grouped_by_employer) { summarize_by_employer(payments, employments, incomes, identities) }
    let(:variables) do
      {
        is_caseworker: true,
        cbv_flow: cbv_flow,
        payments: payments,
        employments: employments,
        incomes: incomes,
        identities: identities,
        payments_grouped_by_employer: payments_grouped_by_employer,
        has_consent: false
      }
    end

    before do
      @pdf_results = PdfService.generate(
        template: 'cbv/summaries/show',
        variables: variables
      )
    end

    context "#generate" do
      it 'generates a PDF file' do
        expect(@pdf_results['content']).to include('%PDF-1.4')
        expect(@pdf_results['html']).to include('Gross pay YTD')
        expect(@pdf_results['html']).to include('Agreement Consent Timestamp')
        expect(File.exist?(@pdf_results['path'])).to be_truthy
        expect(File.size(@pdf_results['path'])).to be > 0
        expect(File.extname(@pdf_results['path'])).to eq('.pdf')
      end
    end

    after do
      @pdf_results['path']&.tap { |path| File.delete(path) if File.exist?(path) }
    end
  end
end
