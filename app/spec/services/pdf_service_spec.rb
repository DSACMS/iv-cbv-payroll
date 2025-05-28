require 'rails_helper'

RSpec.describe PdfService, type: :service do
  include PinwheelApiHelper
  include Cbv::AggregatorDataHelper
  include ApplicationHelper

  let(:current_time) { Date.parse('2024-06-18') }
  let(:cbv_flow) { create(:cbv_flow, :invited) }

  let(:pinwheel_report) { build(:pinwheel_report, :with_pinwheel_account) }
  let(:variables) do
    {
      is_caseworker: true,
      cbv_flow: cbv_flow,
      aggregator_report: pinwheel_report,
      has_consent: false,
      locale: :en
    }
  end


  describe "#generate" do
    around do |ex|
      I18n.with_locale(locale, &ex)
    end

    context "english locale" do
      let(:locale) { :en }
      it 'generates a PDF file' do
      pdf_service = PdfService.new(language: :en)
      @pdf_results = pdf_service.generate(
        renderer: ApplicationController.renderer,
        template: 'cbv/submits/show',
        variables: variables
      )
      expect(@pdf_results&.content).to include('%PDF-1.4')
      expect(@pdf_results&.html).to include('Gross pay YTD')
      expect(@pdf_results&.html).to include('Agreement Consent Timestamp')
      expect(@pdf_results&.file_size).to be > 0
    end
    end


    context "spanish locale" do
      let(:locale) { :es }
      it 'generates a PDF file in english' do
      pdf_service = PdfService.new(language: :en)
      F @pdf_results = pdf_service.generate(
              renderer: ApplicationController.renderer,
              template: 'cbv/submits/show',
              variables: variables
            )
      expect(@pdf_results&.content).to include('%PDF-1.4')
      expect(@pdf_results&.html).to include('Gross pay YTD')
      expect(@pdf_results&.html).to include('Agreement Consent Timestamp')
      expect(@pdf_results&.file_size).to be > 0
    end
    end
  end
end
