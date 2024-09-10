require 'rails_helper'

RSpec.describe PdfService, type: :service do
  include PinwheelApiHelper
  include Cbv::ReportsHelper
  include ApplicationHelper

  let(:current_site) { Rails.application.config.sites["nyc"] }
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
  let(:ma_user) { create(:user, email: "test@example.com", site_id: 'ma') }

  before do
    cbv_flow.pinwheel_accounts.first.update(pinwheel_account_id: "03e29160-f7e7-4a28-b2d8-813640e030d3")
  end

  describe "#generate" do
    it 'generates a PDF file' do
      pdf_service = PdfService.new
      @pdf_results = pdf_service.generate(
        template: 'cbv/summaries/show',
        variables: variables
      )
      expect(@pdf_results&.content).to include('%PDF-1.4')
      expect(@pdf_results&.html).to include('Gross pay YTD')
      expect(@pdf_results&.html).to include('Agreement Consent Timestamp')
      expect(@pdf_results&.file_size).to be > 0
    end
  end
end