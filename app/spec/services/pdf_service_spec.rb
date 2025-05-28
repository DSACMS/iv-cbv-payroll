require 'rails_helper'

RSpec.describe PdfService, type: :service do
  include PinwheelApiHelper
  include Cbv::AggregatorDataHelper
  include ApplicationHelper

  let(:current_time) { Date.parse('2024-06-18') }
  let(:cbv_flow) { create(:cbv_flow, :completed) }

  let(:pinwheel_report) { build(:pinwheel_report, :with_pinwheel_account) }
  let(:variables) do
    {
      is_caseworker: true,
      cbv_flow: cbv_flow,
      aggregator_report: pinwheel_report,
      has_consent: false
    }
  end

  describe "#generate" do
    it 'generates a PDF file' do
      pdf_service = PdfService.new
      @pdf_results = pdf_service.generate(
        renderer: ApplicationController.renderer,
        template: 'cbv/submits/show',
        variables: variables
      )
      expect(@pdf_results&.content).to include('%PDF-1.4')
      expect(@pdf_results&.html).not_to include('Gross pay YTD')
      expect(@pdf_results&.html).to include('Monthly Summary')
      expect(@pdf_results&.html).to include('Agreement Consent Timestamp')
      expect(@pdf_results&.file_size).to be > 0
    end
  end
end
